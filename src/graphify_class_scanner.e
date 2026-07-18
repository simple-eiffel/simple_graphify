note
	description: "[
		Pass 1b/1c: Eiffel class scan. Phase A registers class nodes from
		parsed sources (simple_eiffel_parser). Phase B, once every class is
		known, adds inherits/uses/creates/mentions edges from a comment-aware
		supplier reference scan, mines NOTE:/WHY:/TODO: rationale tags, and
		(deep mode) adds feature-level nodes.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_CLASS_SCANNER

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create scanner feeding `a_graph`.
		do
			graph := a_graph
			create parser.make
			create file_class.make (100)
			create file_content.make (100)
			create file_relative.make (100)
			create class_asts.make (100)
			create class_parents.make (100)
			create known_class_files.make (100)
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Target graph.

	classes_found: INTEGER
			-- Number of classes registered so far.
		do
			Result := class_asts.count
		end

	class_registry: HASH_TABLE [EIFFEL_CLASS_NODE, STRING]
			-- Parsed classes keyed by upper-case name.
		do
			Result := class_asts
		ensure
			result_attached: Result /= Void
		end

feature -- Phase A: registration

	register_file (a_path, a_root: STRING)
			-- Parse `a_path` and register its class node(s).
		require
			path_not_empty: not a_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_content, l_rel, l_name, l_id: STRING
			l_ast: EIFFEL_AST
			l_node: GRAPHIFY_NODE
			l_parents: ARRAYED_LIST [STRING]
			l_failed: BOOLEAN
		do
			if l_failed then
				graph.add_warning ("Parse failed, file skipped: " + a_path)
			else
				create l_file.make (a_path)
				if l_file.found and then l_file.is_file then
					l_content := utf8 (l_file.content)
					l_rel := relative_to (a_root, a_path)
					file_content.force (l_content, a_path)
					file_relative.force (l_rel, a_path)
					l_ast := parser.parse_string (l_content)
					across l_ast.classes as ic_class loop
						l_name := ic_class.name.as_upper
						l_id := "class:" + l_name
						if class_asts.has (l_name) then
							graph.add_warning ("Duplicate class " + l_name + " in " + l_rel)
						else
							create l_node.make (l_id, "class", l_name)
							l_node.set_location (l_rel, ic_class.line)
							if ic_class.header_comment.is_empty then
								l_node.set_description (note_description (l_content))
							else
								l_node.set_description (first_line_of (ic_class.header_comment, 200))
							end
							if ic_class.is_deferred then
								l_node.add_flag ("deferred")
							end
							if ic_class.is_expanded then
								l_node.add_flag ("expanded")
							end
							if ic_class.is_frozen then
								l_node.add_flag ("frozen")
							end
							set_class_metrics (l_node, ic_class, l_content)
							graph.add_node (l_node)
							class_asts.force (ic_class, l_name)
							known_class_files.force (a_path, l_name)
							if not file_class.has (a_path) then
								file_class.force (l_name, a_path)
							end
							create l_parents.make (ic_class.parents.count)
							across ic_class.parents as ic_p loop
								l_parents.extend (ic_p.parent_name.as_upper)
							end
							class_parents.force (l_parents, l_name)
						end
					end
					if l_ast.classes.is_empty then
						graph.add_warning ("No class parsed from " + l_rel)
					end
				else
					graph.add_warning ("Cannot read source: " + a_path)
				end
			end
		rescue
			l_failed := True
			retry
		end

feature -- Phase B: linking

	link_all (a_containments: ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]]; a_deep: BOOLEAN)
			-- Add inherits, containment, supplier, rationale (and deep-mode
			-- feature) edges. Call after every file is registered.
		local
			l_paths: ARRAYED_LIST [STRING]
			l_sorted_containments: ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]]
		do
			l_sorted_containments := containments_by_depth (a_containments)
			create l_paths.make (file_class.count)
			from
				file_class.start
			until
				file_class.after
			loop
				l_paths.extend (file_class.key_for_iteration)
				file_class.forth
			end
			l_paths := merge_sorted (l_paths)
			across l_paths as ic_path loop
				if attached file_class.item (ic_path) as al_name then
					link_file (ic_path, al_name, l_sorted_containments, a_deep)
				end
			end
		end

feature {NONE} -- Linking implementation

	link_file (a_path, a_class_name: STRING; a_containments: ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]]; a_deep: BOOLEAN)
			-- Link class `a_class_name` defined in `a_path`.
		local
			l_class_id: STRING
			l_failed: BOOLEAN
		do
			if l_failed then
				graph.add_warning ("Linking failed for " + a_path)
			else
				l_class_id := "class:" + a_class_name
				add_inherits_edges (a_class_name, l_class_id)
				add_containment_edge (a_path, l_class_id, a_containments)
				if attached file_content.item (a_path) as al_content then
					scan_source (al_content, a_class_name, l_class_id)
				end
				if a_deep and then attached class_asts.item (a_class_name) as al_class then
					add_feature_nodes (al_class, a_class_name, l_class_id)
				end
			end
		rescue
			l_failed := True
			retry
		end

	add_inherits_edges (a_class_name, a_class_id: STRING)
			-- Add inherits edges; unknown parents become external class nodes.
		local
			l_parent_id: STRING
			l_node: GRAPHIFY_NODE
			l_why: STRING
		do
			if attached class_parents.item (a_class_name) as al_parents then
				across al_parents as ic_parent loop
					l_parent_id := "class:" + ic_parent
					if not graph.has_node (l_parent_id) then
						create l_node.make (l_parent_id, "class", ic_parent)
						l_node.add_flag ("external")
						graph.add_node (l_node)
					end
					l_why := "inherit"
					if attached class_asts.item (a_class_name) as al_class then
						across al_class.parents as ic_p loop
							if ic_p.parent_name.as_upper.same_string (ic_parent) then
								if not ic_p.renames.is_empty then
									l_why := l_why + ", renames: " + ic_p.renames.count.out
								end
								if not ic_p.redefines.is_empty then
									l_why := l_why + ", redefines: " + ic_p.redefines.count.out
								end
							end
						end
					end
					graph.connect (a_class_id, l_parent_id, "inherits", "extracted", 0, l_why)
				end
			end
		end

	add_containment_edge (a_path, a_class_id: STRING; a_containments: ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]])
			-- Connect the deepest containing cluster/library to the class.
		local
			l_lower: STRING
			l_done: BOOLEAN
		do
			l_lower := a_path.as_lower
			across a_containments as ic_entry loop
				if not l_done and then l_lower.starts_with (ic_entry.dir.as_lower + "/") then
					graph.connect (ic_entry.node_id, a_class_id, "contains", "extracted", 0, "file location")
					l_done := True
				end
			end
		end

	scan_source (a_content, a_class_name, a_class_id: STRING)
			-- Supplier-reference and rationale scan over `a_content`.
		local
			l_lines: LIST [STRING]
			l_line_no: INTEGER
			l_split: TUPLE [code: STRING; comment: STRING]
			l_tag_count: INTEGER
		do
			l_lines := a_content.split ('%N')
			l_line_no := 0
			l_tag_count := 0
			across l_lines as ic_line loop
				l_line_no := l_line_no + 1
				l_split := split_code_comment (ic_line)
				scan_code_tokens (l_split.code, a_class_name, a_class_id, l_line_no)
				l_tag_count := scan_comment (l_split.comment, a_class_name, a_class_id, l_line_no, l_tag_count)
			end
		end

	scan_code_tokens (a_code, a_class_name, a_class_id: STRING; a_line: INTEGER)
			-- Add uses/creates edges for known-class tokens in code text.
		local
			l_kind, l_target_id: STRING
		do
			across upper_tokens (a_code) as ic_tok loop
				if class_asts.has (ic_tok.token) and then not ic_tok.token.same_string (a_class_name) then
					if not is_parent_of (a_class_name, ic_tok.token) then
						l_target_id := "class:" + ic_tok.token
						if is_creation_context (a_code, ic_tok.position, ic_tok.token) then
							l_kind := "creates"
							graph.connect (a_class_id, l_target_id, l_kind, "extracted", a_line, "creation instruction")
						else
							l_kind := "uses"
							graph.connect (a_class_id, l_target_id, l_kind, "extracted", a_line, "supplier reference")
						end
					end
				end
			end
		end

	scan_comment (a_comment, a_class_name, a_class_id: STRING; a_line, a_tag_count: INTEGER): INTEGER
			-- Add mentions edges and rationale tag nodes from comment text.
			-- Returns updated rationale tag counter.
		local
			l_marker_pos: INTEGER
			l_marker, l_text, l_tag_id: STRING
			l_node: GRAPHIFY_NODE
		do
			Result := a_tag_count
			if not a_comment.is_empty then
				across upper_tokens (a_comment) as ic_tok loop
					if class_asts.has (ic_tok.token) and then not ic_tok.token.same_string (a_class_name) then
						graph.connect (a_class_id, "class:" + ic_tok.token, "mentions", "inferred", a_line, "comment mention")
					end
				end
				l_marker := ""
				l_marker_pos := a_comment.substring_index ("NOTE:", 1)
				if l_marker_pos > 0 then
					l_marker := "NOTE"
				else
					l_marker_pos := a_comment.substring_index ("WHY:", 1)
					if l_marker_pos > 0 then
						l_marker := "WHY"
					else
						l_marker_pos := a_comment.substring_index ("TODO:", 1)
						if l_marker_pos > 0 then
							l_marker := "TODO"
						end
					end
				end
				if not l_marker.is_empty then
					Result := Result + 1
					l_text := a_comment.substring (l_marker_pos, a_comment.count)
					l_text.left_adjust
					l_text.right_adjust
					if l_text.count > 200 then
						l_text := l_text.substring (1, 200)
					end
					l_tag_id := "tag:" + a_class_name + "#" + Result.out
					create l_node.make (l_tag_id, "rationale", l_marker + " in " + a_class_name)
					if attached file_relative.item (file_of_class (a_class_name)) as al_rel then
						l_node.set_location (al_rel, a_line)
					end
					l_node.set_description (l_text)
					graph.add_node (l_node)
					graph.connect (a_class_id, l_tag_id, "mentions", "extracted", a_line, "design note")
				end
			end
		ensure
			counter_monotonic: Result >= a_tag_count
		end

	add_feature_nodes (a_class: EIFFEL_CLASS_NODE; a_class_name, a_class_id: STRING)
			-- Deep mode: one node per feature plus signature-type uses edges.
		local
			l_id: STRING
			l_node: GRAPHIFY_NODE
		do
			across a_class.features as ic_f loop
				l_id := "feature:" + a_class_name + "." + ic_f.name
				if not graph.has_node (l_id) then
					create l_node.make (l_id, "feature", a_class_name + "." + ic_f.name)
					if attached file_relative.item (file_of_class (a_class_name)) as al_rel then
						l_node.set_location (al_rel, ic_f.line)
					end
					l_node.set_description (first_line_of (ic_f.header_comment, 200))
					if ic_f.is_deferred then
						l_node.add_flag ("deferred")
					end
					if ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_attribute then
						l_node.add_flag ("attribute")
					elseif ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_once_function or ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_once_procedure then
						l_node.add_flag ("once")
					elseif ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_external then
						l_node.add_flag ("external")
					end
					l_node.set_metric ("arguments", ic_f.arguments.count)
					if not ic_f.precondition.is_empty then
						l_node.set_metric ("has_precondition", 1)
					end
					if not ic_f.postcondition.is_empty then
						l_node.set_metric ("has_postcondition", 1)
					end
					graph.add_node (l_node)
					graph.connect (a_class_id, l_id, "contains", "extracted", ic_f.line, "feature")
					add_signature_edges (ic_f, l_id, a_class_name)
				end
			end
		end

	add_signature_edges (a_feature: EIFFEL_FEATURE_NODE; a_feature_id, a_class_name: STRING)
			-- Uses edges from a feature's signature/local types to known classes.
		local
			l_types: ARRAYED_LIST [STRING]
		do
			create l_types.make (8)
			if attached a_feature.return_type as al_rt then
				l_types.extend (al_rt)
			end
			across a_feature.arguments as ic_a loop
				l_types.extend (ic_a.arg_type)
			end
			across a_feature.locals as ic_l loop
				l_types.extend (ic_l.local_type)
			end
			across l_types as ic_type loop
				across upper_tokens (ic_type) as ic_tok loop
					if class_asts.has (ic_tok.token) and then not ic_tok.token.same_string (a_class_name) then
						graph.connect (a_feature_id, "class:" + ic_tok.token, "uses", "extracted", a_feature.line, "signature")
					end
				end
			end
		end

feature {NONE} -- Scanning helpers

	split_code_comment (a_line: STRING): TUPLE [code: STRING; comment: STRING]
			-- Split a source line at its "--" comment (string-literal aware).
		local
			i: INTEGER
			l_in_string: BOOLEAN
			l_split: INTEGER
		do
			l_split := 0
			from
				i := 1
			until
				i > a_line.count or l_split > 0
			loop
				if l_in_string then
					if a_line [i] = '%%' then
						i := i + 1
					elseif a_line [i] = '"' then
						l_in_string := False
					end
				else
					if a_line [i] = '"' then
						l_in_string := True
					elseif a_line [i] = '-' and then i < a_line.count and then a_line [i + 1] = '-' then
						l_split := i
					end
				end
				i := i + 1
			end
			if l_split > 0 then
				Result := [a_line.substring (1, l_split - 1), a_line.substring (l_split + 2, a_line.count)]
			else
				Result := [a_line, ""]
			end
		end

	is_parent_of (a_class_name, a_candidate: STRING): BOOLEAN
			-- Is `a_candidate` a declared parent of `a_class_name`?
		do
			if attached class_parents.item (a_class_name) as al_parents then
				across al_parents as ic_p loop
					if ic_p.same_string (a_candidate) then
						Result := True
					end
				end
			end
		end

	is_creation_context (a_code: STRING; a_position: INTEGER; a_token: STRING): BOOLEAN
			-- Is the token at `a_position` written as `create {TOKEN}`?
		local
			l_before: STRING
			l_open: INTEGER
		do
			l_open := a_position - 1
			from
			until
				l_open < 1 or else a_code [l_open] /= ' '
			loop
				l_open := l_open - 1
			end
			if l_open >= 1 and then a_code [l_open] = '{' then
				l_before := a_code.substring (1, l_open - 1)
				l_before.right_adjust
				Result := l_before.ends_with ("create")
			end
		end

	file_of_class (a_class_name: STRING): STRING
			-- Absolute path of the file defining `a_class_name`; empty when unknown.
		do
			if attached known_class_files.item (a_class_name) as al_path then
				Result := al_path
			else
				create Result.make_empty
			end
		ensure
			result_attached: Result /= Void
		end

	set_class_metrics (a_node: GRAPHIFY_NODE; a_class: EIFFEL_CLASS_NODE; a_content: STRING)
			-- Fill class-level metrics from AST + raw content.
		local
			l_queries, l_commands, l_attributes, l_pre, l_post: INTEGER
		do
			across a_class.features as ic_f loop
				if ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_attribute then
					l_attributes := l_attributes + 1
				elseif ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_function or ic_f.kind = {EIFFEL_FEATURE_NODE}.kind_once_function then
					l_queries := l_queries + 1
				else
					l_commands := l_commands + 1
				end
				if not ic_f.precondition.is_empty then
					l_pre := l_pre + 1
				end
				if not ic_f.postcondition.is_empty then
					l_post := l_post + 1
				end
			end
			if l_pre = 0 then
				-- Structural parse carries no contract text (Gobo shallow mode):
				-- fall back to counting require/ensure keyword lines in source.
				l_pre := keyword_line_count (a_content, "require")
			end
			if l_post = 0 then
				l_post := keyword_line_count (a_content, "ensure")
			end
			a_node.set_metric ("features", a_class.features.count)
			a_node.set_metric ("queries", l_queries)
			a_node.set_metric ("commands", l_commands)
			a_node.set_metric ("attributes", l_attributes)
			a_node.set_metric ("preconditions", l_pre)
			a_node.set_metric ("postconditions", l_post)
			a_node.set_metric ("has_invariant", keyword_line_count (a_content, "invariant").min (1))
			a_node.set_metric ("creators", a_class.creators.count)
			a_node.set_metric ("loc", a_content.occurrences ('%N') + 1)
		end

	keyword_line_count (a_content, a_keyword: STRING): INTEGER
			-- Number of lines in `a_content` whose trimmed text is exactly
			-- `a_keyword` (or `a_keyword` + " else"/" then").
		require
			keyword_not_empty: not a_keyword.is_empty
		local
			l_lines: LIST [STRING]
			l_line: STRING
		do
			l_lines := a_content.split ('%N')
			across l_lines as ic_line loop
				l_line := ic_line.twin
				l_line.prune_all ('%R')
				l_line.left_adjust
				l_line.right_adjust
				if l_line.same_string (a_keyword)
					or l_line.same_string (a_keyword + " else")
					or l_line.same_string (a_keyword + " then")
				then
					Result := Result + 1
				end
			end
		ensure
			non_negative: Result >= 0
		end

	note_description (a_content: STRING): STRING
			-- Text of the note clause's description entry; empty when absent.
			-- Handles both one-line strings and verbatim "[ ... ]" blocks
			-- (first non-empty line).
		local
			l_pos, l_quote, i: INTEGER
			l_rest: STRING
		do
			create Result.make_empty
			l_pos := a_content.substring_index ("description:", 1)
			if l_pos > 0 then
				l_quote := a_content.index_of ('"', l_pos)
				if l_quote > 0 and l_quote < a_content.count then
					if a_content [l_quote + 1] = '[' then
						l_rest := a_content.substring (l_quote + 2, (l_quote + 600).min (a_content.count))
						Result := first_line_of (l_rest, 200)
					else
						i := a_content.index_of ('"', l_quote + 1)
						if i > l_quote + 1 then
							Result := first_line_of (a_content.substring (l_quote + 1, i - 1), 200)
						end
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

	containments_by_depth (a_entries: ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]]): ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]]
			-- `a_entries` ordered by descending directory depth (deepest first),
			-- deterministic (key sort).
		local
			l_keys: ARRAYED_LIST [STRING]
			l_by_key: HASH_TABLE [TUPLE [dir: STRING; node_id: STRING], STRING]
			l_key: STRING
		do
			create l_keys.make (a_entries.count)
			create l_by_key.make (a_entries.count)
			across a_entries as ic_entry loop
				l_key := padded_number (9999 - ic_entry.dir.count, 4) + "|" + ic_entry.dir.as_lower + "|" + ic_entry.node_id
				l_keys.extend (l_key)
				l_by_key.force (ic_entry, l_key)
			end
			l_keys := merge_sorted (l_keys)
			create Result.make (l_keys.count)
			across l_keys as ic_key loop
				if attached l_by_key.item (ic_key) as al_entry then
					Result.extend (al_entry)
				end
			end
		ensure
			same_count: Result.count <= a_entries.count
		end

feature {NONE} -- Implementation

	parser: SIMPLE_EIFFEL_PARSER
			-- Shared parser instance.

	file_class: HASH_TABLE [STRING, STRING]
			-- First class name per absolute file path.

	file_content: HASH_TABLE [STRING, STRING]
			-- UTF-8 content per absolute file path.

	file_relative: HASH_TABLE [STRING, STRING]
			-- Root-relative path per absolute file path.

	class_asts: HASH_TABLE [EIFFEL_CLASS_NODE, STRING]
			-- Parsed AST per class name (upper case).

	class_parents: HASH_TABLE [ARRAYED_LIST [STRING], STRING]
			-- Parent names (upper case) per class name.

	known_class_files: HASH_TABLE [STRING, STRING]
			-- Defining absolute file path per class name.

invariant
	graph_attached: graph /= Void

end
