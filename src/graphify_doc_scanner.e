note
	description: "[
		Pass 2: markdown document scan. Each document becomes a node; every
		mention of a scanned class or library becomes a references edge whose
		weight is the mention count.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_DOC_SCANNER

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create scanner feeding `a_graph`.
		do
			graph := a_graph
			documents_found := 0
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Target graph.

	documents_found: INTEGER
			-- Documents registered so far.

feature -- Basic operations

	scan (a_path, a_root: STRING; a_class_names: HASH_TABLE [EIFFEL_CLASS_NODE, STRING]; a_library_ids: HASH_TABLE [STRING, STRING])
			-- Register document at `a_path` and its references to known
			-- classes (`a_class_names` keys) and libraries (`a_library_ids`:
			-- node id per lowercase name).
		require
			path_not_empty: not a_path.is_empty
			root_not_empty: not a_root.is_empty
		local
			l_file: SIMPLE_FILE
			l_content, l_rel, l_doc_id, l_title: STRING
			l_node: GRAPHIFY_NODE
			l_lines: LIST [STRING]
			l_line_no: INTEGER
		do
			create l_file.make (a_path)
			if l_file.found and then l_file.is_file then
				l_content := utf8 (l_file.content)
				l_rel := relative_to (a_root, a_path)
				l_doc_id := "doc:" + l_rel
				create l_node.make (l_doc_id, "document", path_base_stem (l_rel) + ".md")
				l_node.set_location (l_rel, 1)
				l_title := heading_of (l_content)
				if l_title.is_empty then
					l_title := first_line_of (l_content, 200)
				end
				if not l_title.is_empty then
					l_node.set_description (l_title)
				end
				l_node.set_metric ("lines", l_content.occurrences ('%N') + 1)
				graph.add_node (l_node)
				documents_found := documents_found + 1

				l_lines := l_content.split ('%N')
				l_line_no := 0
				across l_lines as ic_line loop
					l_line_no := l_line_no + 1
					across upper_tokens (ic_line) as ic_tok loop
						if a_class_names.has (ic_tok.token) then
							graph.connect (l_doc_id, "class:" + ic_tok.token, "references", "extracted", l_line_no, "documented")
						end
					end
					scan_library_mentions (ic_line, l_doc_id, l_line_no, a_library_ids)
				end
			else
				graph.add_warning ("Cannot read document: " + a_path)
			end
		end

feature {NONE} -- Implementation

	heading_of (a_content: STRING): STRING
			-- First markdown heading text, truncated to 200 chars; empty when none.
		local
			l_lines: LIST [STRING]
			l_line: STRING
		do
			create Result.make_empty
			l_lines := a_content.split ('%N')
			from
				l_lines.start
			until
				l_lines.after or not Result.is_empty
			loop
				l_line := l_lines.item.twin
				l_line.left_adjust
				if l_line.starts_with ("#") then
					from
					until
						l_line.is_empty or else (l_line [1] /= '#' and l_line [1] /= ' ')
					loop
						l_line.remove_head (1)
					end
					l_line.right_adjust
					if not l_line.is_empty then
						Result := first_line_of (l_line, 200)
					end
				end
				l_lines.forth
			end
		ensure
			result_attached: Result /= Void
		end

	scan_library_mentions (a_line, a_doc_id: STRING; a_line_no: INTEGER; a_library_ids: HASH_TABLE [STRING, STRING])
			-- References edges for lowercase library-name words in `a_line`.
		local
			l_lower: STRING
			i, l_start: INTEGER
			l_word: STRING
			l_boundary_ok: BOOLEAN
		do
			l_lower := a_line.as_lower
			from
				i := 1
			until
				i > l_lower.count
			loop
				if is_word_char (l_lower [i]) then
					l_start := i
					from
					until
						i > l_lower.count or else not is_word_char (l_lower [i])
					loop
						i := i + 1
					end
					l_word := l_lower.substring (l_start, i - 1)
					l_boundary_ok := True
					if l_start > 1 and then is_word_char (a_line [l_start - 1]) then
						l_boundary_ok := False
					end
					if l_boundary_ok and then attached a_library_ids.item (l_word) as al_lib_id then
						graph.connect (a_doc_id, al_lib_id, "references", "extracted", a_line_no, "documented")
					end
				else
					i := i + 1
				end
			end
		end

	is_word_char (a_char: CHARACTER): BOOLEAN
			-- Lowercase identifier character?
		do
			Result := (a_char >= 'a' and a_char <= 'z')
				or (a_char >= '0' and a_char <= '9')
				or a_char = '_'
		end

invariant
	graph_attached: graph /= Void
	documents_non_negative: documents_found >= 0

end
