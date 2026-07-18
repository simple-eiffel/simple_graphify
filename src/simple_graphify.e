note
	description: "[
		Facade for simple_graphify: build a knowledge graph from an Eiffel
		project directory, persist/load graph.json, and answer queries.

		Usage:
			create g.make
			if g.build ("D:/prod/simple_http", "", False, True, False) then
				print (g.last_summary)
			end
			if g.load_default (".") then
				print (g.query ("how does the cache work", 1, 30))
			end
	]"
	author: "Larry Rix"

class
	SIMPLE_GRAPHIFY

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Create facade.
		do
			create graph.make
			create json_io.make
			create exclusions.make (4)
			last_error := ""
			last_summary := ""
			last_out_dir := ""
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Current graph (built or loaded).

	last_error: STRING
			-- Problem from the last operation; empty when none.

	last_summary: STRING
			-- Human summary of the last build.

	last_out_dir: STRING
			-- Output directory of the last build.

	has_graph: BOOLEAN
			-- Is a non-empty graph available?
		do
			Result := graph.node_count > 0
		end

	exclusions: ARRAYED_LIST [STRING]
			-- Directory names pruned from the next `build`.

feature -- Configuration

	set_exclusions (a_csv: STRING)
			-- Prune directories named in comma-separated `a_csv` during `build`.
		local
			l_parts: LIST [STRING]
			l_name: STRING
		do
			exclusions.wipe_out
			l_parts := a_csv.split (',')
			across l_parts as ic_p loop
				l_name := ic_p.twin
				l_name.left_adjust
				l_name.right_adjust
				if not l_name.is_empty then
					exclusions.extend (l_name)
				end
			end
		end

feature -- Building

	build (a_root, a_out_dir: STRING; a_deep, a_include_docs, a_full_deps: BOOLEAN): BOOLEAN
			-- Build graph from `a_root`, writing artifacts to `a_out_dir`
			-- (default: <root>/graphify-out). True when Eiffel content found
			-- and artifacts written.
		require
			root_not_empty: not a_root.is_empty
		local
			l_builder: GRAPHIFY_BUILDER
			l_out: STRING
		do
			last_error := ""
			create l_builder.make
			l_builder.set_excluded (exclusions)
			l_builder.build (a_root, a_deep, a_include_docs, a_full_deps)
			graph := l_builder.graph
			if l_builder.built_successfully then
				if a_out_dir.is_empty then
					l_out := graph.root_path + "/graphify-out"
				else
					l_out := normalized_path (a_out_dir)
				end
				last_out_dir := l_out
				Result := write_artifacts (l_out)
				if Result then
					build_summary (l_out)
				end
			else
				last_error := "No Eiffel content (no .e or .ecf files) under " + a_root
			end
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

	write_artifacts (a_out_dir: STRING): BOOLEAN
			-- Write graph.json, GRAPH_REPORT.md, graph.html, graph.dot to `a_out_dir`.
		require
			out_not_empty: not a_out_dir.is_empty
		local
			l_dir: SIMPLE_FILE
			l_json: STRING
			l_report: GRAPHIFY_REPORT
			l_html: GRAPHIFY_HTML
			l_dot: GRAPHIFY_DOT
		do
			create l_dir.make (a_out_dir)
			if l_dir.create_directory_recursive or l_dir.is_directory then
				l_json := json_io.serialized (graph)
				Result := write_text (a_out_dir + "/graph.json", l_json)
				create l_report.make (graph)
				Result := write_text (a_out_dir + "/GRAPH_REPORT.md", l_report.report_text) and Result
				create l_html.make
				Result := write_text (a_out_dir + "/graph.html", l_html.html_text (l_json)) and Result
				create l_dot.make (graph)
				Result := write_text (a_out_dir + "/graph.dot", l_dot.dot_text) and Result
				if not Result then
					last_error := "Failed writing artifacts to " + a_out_dir
				end
			else
				last_error := "Cannot create output directory " + a_out_dir
			end
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

feature -- Loading

	load (a_graph_path: STRING): BOOLEAN
			-- Load graph.json at `a_graph_path` into `graph`.
		require
			path_not_empty: not a_graph_path.is_empty
		local
			l_file: SIMPLE_FILE
		do
			last_error := ""
			create l_file.make (a_graph_path)
			if l_file.found and then l_file.is_file then
				if attached json_io.loaded (utf8 (l_file.content)) as al_graph then
					graph := al_graph
					Result := True
				else
					last_error := json_io.last_error + " (" + a_graph_path + ")"
				end
			else
				last_error := "Graph file not found: " + a_graph_path
			end
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

	load_default (a_dir: STRING): BOOLEAN
			-- Load ./graphify-out/graph.json, else ./graph.json, under `a_dir`.
		require
			dir_not_empty: not a_dir.is_empty
		local
			l_probe: SIMPLE_FILE
			l_base: STRING
		do
			l_base := normalized_path (a_dir)
			create l_probe.make (l_base + "/graphify-out/graph.json")
			if l_probe.found and then l_probe.is_file then
				Result := load (l_base + "/graphify-out/graph.json")
			else
				Result := load (l_base + "/graph.json")
			end
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

feature -- Queries

	query (a_question: STRING; a_hops, a_limit: INTEGER): STRING
			-- Markdown answer for `a_question`.
		require
			graph_loaded: has_graph
			question_not_empty: not a_question.is_empty
			hops_non_negative: a_hops >= 0
			limit_positive: a_limit >= 1
		local
			l_engine: GRAPHIFY_QUERY
		do
			create l_engine.make (graph)
			Result := l_engine.answer (a_question, a_hops, a_limit)
		ensure
			result_not_empty: not Result.is_empty
		end

	explain (a_name: STRING): STRING
			-- Markdown record of the node resolved from `a_name`.
		require
			graph_loaded: has_graph
			name_not_empty: not a_name.is_empty
		local
			l_engine: GRAPHIFY_QUERY
		do
			create l_engine.make (graph)
			Result := l_engine.explain (a_name)
		ensure
			result_not_empty: not Result.is_empty
		end

	path_between (a_from, a_to: STRING): STRING
			-- Markdown shortest connection between two names.
		require
			graph_loaded: has_graph
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
		local
			l_engine: GRAPHIFY_QUERY
		do
			create l_engine.make (graph)
			Result := l_engine.path_between (a_from, a_to)
		ensure
			result_not_empty: not Result.is_empty
		end

	stats: STRING
			-- Markdown statistics of the loaded graph.
		require
			graph_loaded: has_graph
		local
			l_engine: GRAPHIFY_QUERY
		do
			create l_engine.make (graph)
			Result := l_engine.stats_text
		ensure
			result_not_empty: not Result.is_empty
		end

	report: STRING
			-- GRAPH_REPORT.md content regenerated from the loaded graph.
		require
			graph_loaded: has_graph
		local
			l_report: GRAPHIFY_REPORT
		do
			create l_report.make (graph)
			Result := l_report.report_text
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Annotation

	annotate (a_edges_path, a_graph_path: STRING): STRING
			-- Merge assistant-inferred edges from `a_edges_path` into the graph
			-- at `a_graph_path`, re-analyze, rewrite it. Returns a summary.
			-- Sets `last_error` when nothing merged.
		require
			edges_not_empty: not a_edges_path.is_empty
			graph_path_not_empty: not a_graph_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_quick: SIMPLE_JSON_QUICK
			l_merged, l_rejected: INTEGER
			l_from, l_to, l_kind, l_why: STRING
			l_analyzer: GRAPHIFY_ANALYZER
			i: INTEGER
			l_json_io: GRAPHIFY_JSON_IO
		do
			last_error := ""
			create Result.make (256)
			if load (a_graph_path) then
				create l_file.make (a_edges_path)
				if l_file.found and then l_file.is_file then
					create l_quick.make
					if attached l_quick.parse_object (utf8 (l_file.content)) as al_root
						and then attached al_root.array_item ("edges") as al_edges
					then
						from
							i := 1
						until
							i > al_edges.count
						loop
							if attached al_edges.object_item (i) as al_obj then
								l_from := json_string (al_obj, "from")
								l_to := json_string (al_obj, "to")
								l_kind := json_string (al_obj, "kind")
								l_why := json_string (al_obj, "why")
								if l_kind.is_empty then
									l_kind := "references"
								end
								if graph.has_node (l_from) and graph.has_node (l_to) and not l_from.same_string (l_to) then
									graph.connect (l_from, l_to, l_kind, "inferred", 0, l_why)
									l_merged := l_merged + 1
								else
									l_rejected := l_rejected + 1
									Result.append ("Rejected (unknown endpoint): " + l_from + " -> " + l_to + "%N")
								end
							end
							i := i + 1
						end
						if l_merged > 0 then
							create l_analyzer.make (graph)
							l_analyzer.analyze
							create l_json_io.make
							if write_text (a_graph_path, l_json_io.serialized (graph)) then
								Result.append ("Merged " + l_merged.out + " edge(s), rejected "
									+ l_rejected.out + ". Graph updated: " + a_graph_path + "%N")
							else
								last_error := "Could not rewrite " + a_graph_path
							end
						else
							last_error := "No edges merged (all rejected or file empty)"
						end
					else
						last_error := "Invalid edges file (expected {%"edges%": [...]}): " + a_edges_path
					end
				else
					last_error := "Edges file not found: " + a_edges_path
				end
			end
			if not last_error.is_empty then
				Result.append (last_error + "%N")
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Installation

	install_skill (a_project_dir, a_exe_path: STRING): BOOLEAN
			-- Write the Claude Code skill into `a_project_dir`.
		require
			project_not_empty: not a_project_dir.is_empty
			exe_not_empty: not a_exe_path.is_empty
		local
			l_writer: GRAPHIFY_SKILL_WRITER
		do
			last_error := ""
			create l_writer.make
			Result := l_writer.install (a_project_dir, a_exe_path)
			if not Result then
				last_error := l_writer.last_error
			end
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

feature {NONE} -- Implementation

	json_io: GRAPHIFY_JSON_IO
			-- Serializer/loader.

	write_text (a_path, a_content: STRING): BOOLEAN
			-- Write UTF-8 `a_content` to `a_path`.
		local
			l_file: SIMPLE_FILE
		do
			create l_file.make (a_path)
			Result := l_file.set_content (utf8_to_string_32 (a_content))
		end

	json_string (a_object: SIMPLE_JSON_OBJECT; a_key: STRING): STRING
			-- UTF-8 string at `a_key`; empty when absent.
		do
			if attached a_object.string_item (a_key.to_string_32) as al_v then
				Result := utf8 (al_v)
			else
				create Result.make_empty
			end
		ensure
			result_attached: Result /= Void
		end

	build_summary (a_out_dir: STRING)
			-- Compose `last_summary` after a successful build.
		local
			l_shown: INTEGER
		do
			create last_summary.make (512)
			last_summary.append ("Knowledge graph built from " + graph.root_path + "%N")
			last_summary.append ("  Files: " + graph.files_scanned.out
				+ "  Classes: " + graph.classes_scanned.out
				+ "  Documents: " + graph.documents_scanned.out + "%N")
			last_summary.append ("  Nodes: " + graph.node_count.out
				+ "  Edges: " + graph.edge_count.out
				+ "  Communities: " + graph.communities.count.out + "%N")
			last_summary.append ("  God nodes:%N")
			l_shown := 0
			across graph.god_node_ids as ic_id loop
				if l_shown < 5 and then attached graph.node_by_id (ic_id) as al_node then
					l_shown := l_shown + 1
					last_summary.append ("    " + l_shown.out + ". " + al_node.label
						+ " (degree " + al_node.degree.out + ")%N")
				end
			end
			last_summary.append ("  Output: " + a_out_dir + "/graph.json | GRAPH_REPORT.md | graph.html | graph.dot%N")
			if not graph.warnings.is_empty then
				last_summary.append ("  Warnings: " + graph.warnings.count.out + " (see GRAPH_REPORT.md)%N")
			end
		end

invariant
	graph_attached: graph /= Void

end
