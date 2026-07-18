note
	description: "[
		Pass 1a: ECF configuration scan. Extracts library identity, library
		dependencies, and cluster topology using tolerant tag/attribute string
		scanning (namespace-proof; same approach as claude_tools uuid scan).
	]"
	author: "Larry Rix"

class
	GRAPHIFY_ECF_SCANNER

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create scanner feeding `a_graph`.
		do
			graph := a_graph
			create containment_entries.make (20)
			create library_name_ids.make (10)
			create containment_keys.make (20)
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Target graph.

	containment_entries: ARRAYED_LIST [TUPLE [dir: STRING; node_id: STRING]]
			-- Absolute directory prefixes mapped to containing cluster/library node ids.

	library_name_ids: HASH_TABLE [STRING, STRING]
			-- Library node ids keyed by lowercase library name (for doc matching).

feature -- Basic operations

	scan (a_path, a_root: STRING; a_full_deps: BOOLEAN)
			-- Scan ECF at absolute path `a_path` (root `a_root`); when
			-- `a_full_deps`, external ISE/Gobo dependencies become nodes too.
		require
			path_not_empty: not a_path.is_empty
			root_not_empty: not a_root.is_empty
		local
			l_file: SIMPLE_FILE
			l_content, l_ecf_dir, l_rel: STRING
			l_library_id: STRING
			i: INTEGER
			l_tag: TUPLE [name: STRING; body: STRING; position: INTEGER]
		do
			create l_file.make (a_path)
			if l_file.found and then l_file.is_file then
				l_content := utf8 (l_file.content)
				l_ecf_dir := parent_directory (a_path)
				l_rel := relative_to (a_root, a_path)
				l_library_id := ""
				from
					i := 1
				until
					i > l_content.count
				loop
					l_tag := next_tag (l_content, i)
					if l_tag.name.is_empty then
						i := l_content.count + 1
					else
						i := l_tag.position
						if l_tag.name.same_string ("system") then
							l_library_id := register_system (l_tag.body, l_content, l_rel, l_ecf_dir)
						elseif l_tag.name.same_string ("library") and not l_library_id.is_empty then
							register_library_reference (l_tag.body, l_library_id, a_full_deps, line_at (l_content, i))
						elseif l_tag.name.same_string ("cluster") and not l_library_id.is_empty then
							register_cluster (l_tag.body, l_library_id, l_ecf_dir, l_rel, line_at (l_content, i))
						end
					end
				end
			else
				graph.add_warning ("Cannot read ECF: " + a_path)
			end
		end

feature {NONE} -- Implementation

	containment_keys: HASH_TABLE [BOOLEAN, STRING]
			-- Dedup for containment entries.

	register_system (a_attrs, a_content, a_rel_path, a_ecf_dir: STRING): STRING
			-- Create the library node from a <system> tag; return its node id.
		local
			l_name, l_id, l_desc: STRING
			l_node: GRAPHIFY_NODE
		do
			l_name := attribute_value (a_attrs, "name")
			if l_name.is_empty then
				l_name := path_base_stem (a_rel_path)
			end
			l_id := "library:" + l_name.as_lower
			create l_node.make (l_id, "library", l_name)
			l_node.set_location (a_rel_path, 1)
			l_desc := element_text (a_content, "description")
			if not l_desc.is_empty then
				l_node.set_description (first_line_of (l_desc, 200))
			end
			graph.add_node (l_node)
			library_name_ids.force (l_id, l_name.as_lower)
			add_containment (a_ecf_dir, l_id)
			Result := l_id
		ensure
			id_not_empty: not Result.is_empty
		end

	register_library_reference (a_attrs, a_library_id: STRING; a_full_deps: BOOLEAN; a_line: INTEGER)
			-- Create depends_on edge (and target node) from a <library> tag.
		local
			l_location, l_stem, l_target_id: STRING
			l_external: BOOLEAN
			l_node: GRAPHIFY_NODE
		do
			l_location := normalized_path (attribute_value (a_attrs, "location"))
			if not l_location.is_empty then
				l_external := l_location.as_upper.has_substring ("$ISE") or l_location.as_upper.has_substring ("$GOBO")
				l_stem := path_base_stem (l_location).as_lower
				if l_stem.same_string ("library") then
					-- Gobo-style library.ecf: use the parent directory name.
					l_stem := path_base_stem (parent_directory (l_location)).as_lower
				end
				if not l_stem.is_empty and (not l_external or a_full_deps) then
					l_target_id := "library:" + l_stem
					if not graph.has_node (l_target_id) then
						create l_node.make (l_target_id, "library", l_stem)
						if l_external then
							l_node.add_flag ("external")
						end
						graph.add_node (l_node)
					end
					graph.connect (a_library_id, l_target_id, "depends_on", "extracted", a_line, "ecf library reference")
				end
			end
		end

	register_cluster (a_attrs, a_library_id, a_ecf_dir, a_rel_path: STRING; a_line: INTEGER)
			-- Create cluster node + contains edge from a <cluster> tag.
		local
			l_name, l_location, l_id, l_dir: STRING
			l_node: GRAPHIFY_NODE
		do
			l_name := attribute_value (a_attrs, "name")
			l_location := normalized_path (attribute_value (a_attrs, "location"))
			if not l_name.is_empty and not l_location.is_empty and not l_location.has ('$') then
				if l_location.starts_with ("./") then
					l_location := l_location.substring (3, l_location.count)
				end
				if l_location.ends_with ("/") then
					l_location := l_location.substring (1, l_location.count - 1)
				end
				l_id := "cluster:" + a_library_id.substring (9, a_library_id.count) + "/" + l_name
				if not graph.has_node (l_id) then
					create l_node.make (l_id, "cluster", l_name)
					l_node.set_location (a_rel_path, a_line)
					graph.add_node (l_node)
				end
				graph.connect (a_library_id, l_id, "contains", "extracted", a_line, "ecf cluster")
				if l_location.is_empty then
					l_dir := a_ecf_dir
				else
					l_dir := a_ecf_dir + "/" + l_location
				end
				add_containment (l_dir, l_id)
			end
		end

	add_containment (a_dir, a_node_id: STRING)
			-- Record that files under `a_dir` belong to node `a_node_id`.
		local
			l_key: STRING
		do
			l_key := a_dir.as_lower + "|" + a_node_id
			if not containment_keys.has (l_key) then
				containment_keys.put (True, l_key)
				containment_entries.extend ([a_dir, a_node_id])
			end
		end

	next_tag (a_content: STRING; a_start: INTEGER): TUPLE [name: STRING; body: STRING; position: INTEGER]
			-- Next XML *element* tag at or after `a_start`: element name,
			-- attribute body, and the position just past the closing '>'.
			-- Prolog (<?), comments, and closing tags (</) are skipped.
			-- Empty name = no more tags.
		require
			start_positive: a_start >= 1
		local
			l_open, l_close, l_search, i: INTEGER
			l_name: STRING
			l_done: BOOLEAN
		do
			Result := ["", "", a_content.count + 1]
			from
				l_search := a_start
			until
				l_done
			loop
				l_open := a_content.index_of ('<', l_search)
				if l_open = 0 or l_open >= a_content.count then
					l_done := True
				else
					l_close := a_content.index_of ('>', l_open)
					if l_close = 0 then
						l_done := True
					elseif a_content [l_open + 1].is_alpha or a_content [l_open + 1] = '_' then
						create l_name.make (12)
						from
							i := l_open + 1
						until
							i >= l_close or else not (a_content [i].is_alpha or a_content [i] = '_')
						loop
							l_name.append_character (a_content [i])
							i := i + 1
						end
						Result := [l_name.as_lower, a_content.substring (i, l_close - 1), l_close + 1]
						l_done := True
					else
						-- Prolog, comment, or closing tag: keep scanning.
						l_search := l_close + 1
					end
				end
			end
		ensure
			position_advances: Result.position > a_start
		end

	attribute_value (a_attrs, a_name: STRING): STRING
			-- Value of attribute `a_name` inside tag body `a_attrs`; empty when absent.
		require
			name_not_empty: not a_name.is_empty
		local
			l_pattern: STRING
			l_pos, l_quote_start, l_quote_end: INTEGER
			l_before_ok: BOOLEAN
		do
			create Result.make_empty
			l_pattern := a_name + "="
			l_pos := a_attrs.substring_index (l_pattern, 1)
			from
			until
				l_pos = 0 or not Result.is_empty
			loop
				l_before_ok := l_pos = 1 or else not (a_attrs [l_pos - 1].is_alpha or a_attrs [l_pos - 1] = '_')
				if l_before_ok then
					l_quote_start := l_pos + l_pattern.count
					if l_quote_start <= a_attrs.count and then a_attrs [l_quote_start] = '"' then
						l_quote_end := a_attrs.index_of ('"', l_quote_start + 1)
						if l_quote_end > l_quote_start then
							Result := a_attrs.substring (l_quote_start + 1, l_quote_end - 1)
						end
					end
				end
				if Result.is_empty then
					l_pos := a_attrs.substring_index (l_pattern, l_pos + 1)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	element_text (a_content, a_element: STRING): STRING
			-- Text of first <a_element>...</a_element> in `a_content`; empty when absent.
		require
			element_not_empty: not a_element.is_empty
		local
			l_open_tag, l_close_tag: STRING
			l_open, l_after_open, l_close: INTEGER
		do
			create Result.make_empty
			l_open_tag := "<" + a_element + ">"
			l_close_tag := "</" + a_element + ">"
			l_open := a_content.substring_index (l_open_tag, 1)
			if l_open > 0 then
				l_after_open := l_open + l_open_tag.count
				l_close := a_content.substring_index (l_close_tag, l_after_open)
				if l_close > l_after_open then
					Result := a_content.substring (l_after_open, l_close - 1)
					Result.left_adjust
					Result.right_adjust
				end
			end
		ensure
			result_attached: Result /= Void
		end

	parent_directory (a_path: STRING): STRING
			-- Directory part of `a_path` ('/' separators); "." when none.
		local
			l_slash: INTEGER
		do
			l_slash := a_path.last_index_of ('/', a_path.count)
			if l_slash > 1 then
				Result := a_path.substring (1, l_slash - 1)
			else
				Result := "."
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	line_at (a_content: STRING; a_position: INTEGER): INTEGER
			-- 1-based line number of `a_position` in `a_content`.
		require
			position_positive: a_position >= 1
		local
			i: INTEGER
		do
			Result := 1
			from
				i := 1
			until
				i >= a_position or i > a_content.count
			loop
				if a_content [i] = '%N' then
					Result := Result + 1
				end
				i := i + 1
			end
		ensure
			line_positive: Result >= 1
		end

invariant
	graph_attached: graph /= Void

end
