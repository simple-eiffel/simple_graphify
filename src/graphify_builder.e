note
	description: "[
		Build orchestrator: walks a root directory, runs the ECF, class, and
		document scanners, then the analyzer, producing a fully analyzed
		GRAPHIFY_GRAPH.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_BUILDER

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Create builder.
		do
			create graph.make
			create excluded_names.make (4)
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Result of the last `build`.

	built_successfully: BOOLEAN
			-- Did the last `build` find Eiffel content?

	excluded_names: ARRAYED_LIST [STRING]
			-- Extra directory names pruned from the walk.

feature -- Configuration

	set_excluded (a_names: ARRAYED_LIST [STRING])
			-- Prune directories named as in `a_names` during `build`.
		do
			excluded_names := a_names
		ensure
			set: excluded_names = a_names
		end

feature -- Basic operations

	build (a_root: STRING; a_deep, a_include_docs, a_full_deps: BOOLEAN)
			-- Build knowledge graph from directory `a_root`.
		require
			root_not_empty: not a_root.is_empty
		local
			l_fs: GRAPHIFY_FS
			l_ecf_scanner: GRAPHIFY_ECF_SCANNER
			l_class_scanner: GRAPHIFY_CLASS_SCANNER
			l_doc_scanner: GRAPHIFY_DOC_SCANNER
			l_analyzer: GRAPHIFY_ANALYZER
			l_root: STRING
			l_clock: SIMPLE_DATETIME
			l_class_names: HASH_TABLE [EIFFEL_CLASS_NODE, STRING]
		do
			create graph.make
			built_successfully := False
			l_root := normalized_path (a_root)
			if l_root.ends_with ("/") then
				l_root := l_root.substring (1, l_root.count - 1)
			end

			create l_fs.make
			l_fs.set_excluded (excluded_names)
			l_fs.collect (l_root)

			create l_ecf_scanner.make (graph)
			across l_fs.ecf_files as ic_ecf loop
				l_ecf_scanner.scan (ic_ecf, l_root, a_full_deps)
			end

			create l_class_scanner.make (graph)
			across l_fs.eiffel_files as ic_e loop
				l_class_scanner.register_file (ic_e, l_root)
			end
			l_class_scanner.link_all (l_ecf_scanner.containment_entries, a_deep)

			create l_doc_scanner.make (graph)
			if a_include_docs then
				l_class_names := l_class_scanner.class_registry
				across l_fs.doc_files as ic_doc loop
					l_doc_scanner.scan (ic_doc, l_root, l_class_names, l_ecf_scanner.library_name_ids)
				end
			end

			create l_analyzer.make (graph)
			l_analyzer.analyze

			create l_clock.make
			if a_deep then
				graph.set_meta (l_root, "deep", l_clock.now.to_iso8601)
			else
				graph.set_meta (l_root, "standard", l_clock.now.to_iso8601)
			end
			graph.set_scan_counts (l_fs.total_count, l_class_scanner.classes_found, l_doc_scanner.documents_found)

			built_successfully := l_class_scanner.classes_found > 0 or l_fs.ecf_files.count > 0
		end

end
