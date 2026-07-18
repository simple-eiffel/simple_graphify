note
	description: "Tests for simple_graphify (built against the toy_project fixture)"
	author: "Larry Rix"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Access

	Fixture_root: STRING = "data/input/toy_project"
	Out_dir: STRING = "data/output/toy-out"
	Deep_out_dir: STRING = "data/output/toy-deep"

	built_facade: SIMPLE_GRAPHIFY
			-- Facade holding the standard-mode toy graph (built once).
		local
			l_ok: BOOLEAN
		do
			if attached internal_facade as al_f then
				Result := al_f
			else
				create Result.make
				l_ok := Result.build (Fixture_root, Out_dir, False, True, False)
				assert ("fixture_build_ok: " + Result.last_error, l_ok)
				internal_facade := Result
			end
		end

	deep_facade: SIMPLE_GRAPHIFY
			-- Facade holding the deep-mode toy graph (built once).
		local
			l_ok: BOOLEAN
		do
			if attached internal_deep_facade as al_f then
				Result := al_f
			else
				create Result.make
				l_ok := Result.build (Fixture_root, Deep_out_dir, True, True, False)
				assert ("fixture_deep_build_ok: " + Result.last_error, l_ok)
				internal_deep_facade := Result
			end
		end

feature -- Tests: build

	test_build_succeeds
			-- Build writes all four artifacts.
		local
			l_file: SIMPLE_FILE
		do
			assert ("has_graph", built_facade.has_graph)
			create l_file.make (Out_dir + "/graph.json")
			assert ("json_written", l_file.found and then l_file.is_file)
			create l_file.make (Out_dir + "/GRAPH_REPORT.md")
			assert ("report_written", l_file.found and then l_file.is_file)
			create l_file.make (Out_dir + "/graph.html")
			assert ("html_written", l_file.found and then l_file.is_file)
			create l_file.make (Out_dir + "/graph.dot")
			assert ("dot_written", l_file.found and then l_file.is_file)
		end

	test_library_and_clusters
			-- ECF scan: library, clusters, dependency edge.
		local
			g: GRAPHIFY_GRAPH
		do
			g := built_facade.graph
			assert ("library_node", g.has_node ("library:toy_lib"))
			assert ("core_cluster", g.has_node ("cluster:toy_lib/core"))
			assert ("extras_cluster", g.has_node ("cluster:toy_lib/extras"))
			assert ("dep_edge", attached g.edge_between ("library:toy_lib", "library:simple_json") as al_e
				and then al_e.kind.same_string ("depends_on"))
			assert ("base_excluded", not g.has_node ("library:base"))
		end

	test_class_nodes
			-- All five fixture classes registered with flags and descriptions.
		local
			g: GRAPHIFY_GRAPH
		do
			g := built_facade.graph
			assert ("animal", g.has_node ("class:TOY_ANIMAL"))
			assert ("dog", g.has_node ("class:TOY_DOG"))
			assert ("bone", g.has_node ("class:TOY_BONE"))
			assert ("cat", g.has_node ("class:TOY_CAT"))
			assert ("registry", g.has_node ("class:TOY_REGISTRY"))
			assert ("animal_deferred", attached g.node_by_id ("class:TOY_ANIMAL") as al_n
				and then al_n.has_flag ("deferred"))
			assert ("bone_described", attached g.node_by_id ("class:TOY_BONE") as al_b
				and then not al_b.description.is_empty)
		end

	test_inherits_edges
			-- Dog and cat inherit from animal.
		local
			g: GRAPHIFY_GRAPH
		do
			g := built_facade.graph
			assert ("dog_inherits", edge_kind_present (g, "class:TOY_DOG", "class:TOY_ANIMAL", "inherits"))
			assert ("cat_inherits", edge_kind_present (g, "class:TOY_CAT", "class:TOY_ANIMAL", "inherits"))
		end

	test_creates_edge
			-- `create {TOY_BONE}` in TOY_DOG is a creates edge.
		do
			assert ("dog_creates_bone", edge_kind_present (built_facade.graph, "class:TOY_DOG", "class:TOY_BONE", "creates"))
		end

	test_uses_edges
			-- Supplier references become uses edges.
		local
			g: GRAPHIFY_GRAPH
		do
			g := built_facade.graph
			assert ("registry_uses_dog", edge_kind_present (g, "class:TOY_REGISTRY", "class:TOY_DOG", "uses"))
			assert ("registry_uses_cat", edge_kind_present (g, "class:TOY_REGISTRY", "class:TOY_CAT", "uses"))
			assert ("cat_uses_bone", edge_kind_present (g, "class:TOY_CAT", "class:TOY_BONE", "uses"))
		end

	test_mentions_edge
			-- TOY_CAT appears only in a TOY_DOG comment: mentions, inferred.
		local
			g: GRAPHIFY_GRAPH
			l_found, l_inferred: BOOLEAN
		do
			g := built_facade.graph
			across g.edges_from ("class:TOY_DOG") as ic_e loop
				if ic_e.to_id.same_string ("class:TOY_CAT") and ic_e.kind.same_string ("mentions") then
					l_found := True
					l_inferred := ic_e.confidence.same_string ("inferred")
				end
			end
			assert ("mention_found", l_found)
			assert ("mention_inferred", l_inferred)
		end

	test_rationale_tags
			-- NOTE:/WHY:/TODO: comments become rationale nodes.
		local
			g: GRAPHIFY_GRAPH
			l_rationales: INTEGER
			l_todo_found: BOOLEAN
		do
			g := built_facade.graph
			across g.nodes as ic_n loop
				if ic_n.kind.same_string ("rationale") then
					l_rationales := l_rationales + 1
					if ic_n.description.has_substring ("TODO:") and ic_n.id.has_substring ("TOY_REGISTRY") then
						l_todo_found := True
					end
				end
			end
			assert ("three_tags", l_rationales >= 3)
			assert ("registry_todo", l_todo_found)
		end

	test_metrics
			-- TOY_BONE metrics: 3 features, contracts counted.
		do
			assert ("bone_metrics", attached built_facade.graph.node_by_id ("class:TOY_BONE") as al_b
				and then (al_b.metric ("features") = 3
					and al_b.metric ("preconditions") >= 1
					and al_b.metric ("postconditions") >= 2
					and al_b.metric ("loc") > 10))
		end

	test_doc_nodes
			-- Markdown docs registered and referencing classes.
		local
			g: GRAPHIFY_GRAPH
		do
			g := built_facade.graph
			assert ("readme", g.has_node ("doc:README.md"))
			assert ("design", g.has_node ("doc:docs/design.md"))
			assert ("readme_refs_animal", edge_kind_present (g, "doc:README.md", "class:TOY_ANIMAL", "references"))
			assert ("design_refs_registry", edge_kind_present (g, "doc:docs/design.md", "class:TOY_REGISTRY", "references"))
		end

feature -- Tests: analysis

	test_degrees_and_god_nodes
			-- Degrees computed, god list ranked descending.
		local
			g: GRAPHIFY_GRAPH
			l_prev: INTEGER
			l_ranked: BOOLEAN
		do
			g := built_facade.graph
			assert ("gods_present", not g.god_node_ids.is_empty)
			l_prev := {INTEGER}.max_value
			l_ranked := True
			across g.god_node_ids as ic_id loop
				if attached g.node_by_id (ic_id) as al_n then
					if al_n.degree > l_prev then
						l_ranked := False
					end
					l_prev := al_n.degree
				else
					l_ranked := False
				end
			end
			assert ("gods_ranked_descending", l_ranked)
		end

	test_communities_cover_all
			-- Every node belongs to exactly one community.
		local
			g: GRAPHIFY_GRAPH
			l_total: INTEGER
			l_all_labeled, l_all_assigned: BOOLEAN
		do
			g := built_facade.graph
			assert ("some_communities", not g.communities.is_empty)
			l_all_labeled := True
			across g.communities as ic_c loop
				l_total := l_total + ic_c.size
				if ic_c.label.is_empty then
					l_all_labeled := False
				end
			end
			assert ("all_labeled", l_all_labeled)
			assert ("full_cover", l_total = g.node_count)
			l_all_assigned := True
			across g.nodes as ic_n loop
				if ic_n.community < 1 then
					l_all_assigned := False
				end
			end
			assert ("all_assigned", l_all_assigned)
		end

	test_determinism
			-- Two builds serialize identically (modulo timestamp).
		local
			l_a, l_b: SIMPLE_GRAPHIFY
			l_io: GRAPHIFY_JSON_IO
			l_ok_a, l_ok_b: BOOLEAN
		do
			create l_a.make
			l_ok_a := l_a.build (Fixture_root, "data/output/det-a", False, True, False)
			assert ("det_a_built", l_ok_a)
			create l_b.make
			l_ok_b := l_b.build (Fixture_root, "data/output/det-b", False, True, False)
			assert ("det_b_built", l_ok_b)
			create l_io.make
			assert ("identical_serialization",
				without_timestamp (l_io.serialized (l_a.graph)).same_string (without_timestamp (l_io.serialized (l_b.graph))))
		end

	test_json_roundtrip
			-- Serialize -> load preserves counts and structure.
		local
			l_io: GRAPHIFY_JSON_IO
			g: GRAPHIFY_GRAPH
			l_loaded: detachable GRAPHIFY_GRAPH
		do
			create l_io.make
			g := built_facade.graph
			l_loaded := l_io.loaded (l_io.serialized (g))
			assert ("roundtrip_loaded", l_loaded /= Void)
			if attached l_loaded as al_g then
				assert ("nodes_kept", al_g.node_count = g.node_count)
				assert ("edges_kept", al_g.edge_count = g.edge_count)
				assert ("communities_kept", al_g.communities.count = g.communities.count)
				assert ("gods_kept", al_g.god_node_ids.count = g.god_node_ids.count)
				assert ("dog_kept", al_g.has_node ("class:TOY_DOG"))
			end
		end

feature -- Tests: queries

	test_query_hits
			-- Query finds TOY_DOG for "dog".
		local
			l_answer: STRING
		do
			l_answer := built_facade.query ("how does the dog work", 1, 30)
			assert ("dog_matched", l_answer.has_substring ("TOY_DOG"))
			assert ("has_connections", l_answer.has_substring ("## Connections"))
		end

	test_query_miss
			-- Unmatched query degrades gracefully.
		local
			l_answer: STRING
		do
			l_answer := built_facade.query ("zzzqqqxxx", 1, 30)
			assert ("miss_reported", l_answer.has_substring ("No graph nodes matched"))
		end

	test_explain
			-- Explain resolves exact and substring names.
		local
			l_text, l_sub: STRING
		do
			l_text := built_facade.explain ("TOY_BONE")
			assert ("has_title", l_text.has_substring ("TOY_BONE"))
			assert ("has_incoming", l_text.has_substring ("Incoming"))
			l_sub := built_facade.explain ("bone")
			assert ("substring_resolves", l_sub.has_substring ("TOY_BONE"))
		end

	test_path
			-- Path between registry and bone exists.
		local
			l_text, l_same: STRING
		do
			l_text := built_facade.path_between ("TOY_REGISTRY", "TOY_BONE")
			assert ("path_found", l_text.has_substring ("Path:"))
			l_same := built_facade.path_between ("TOY_REGISTRY", "TOY_REGISTRY")
			assert ("no_ghost_path", l_same.has_substring ("same node"))
		end

	test_stats
			-- Stats text lists node and edge kinds.
		local
			l_text: STRING
		do
			l_text := built_facade.stats
			assert ("has_kinds", l_text.has_substring ("Nodes by kind"))
			assert ("has_class_kind", l_text.has_substring ("- class:"))
		end

	test_annotate
			-- Assistant edges merge as inferred; unknown endpoints rejected.
		local
			l_file: SIMPLE_FILE
			l_result: STRING
			l_facade: SIMPLE_GRAPHIFY
			l_ok, l_loaded: BOOLEAN
		do
			assert ("base_built", built_facade.has_graph)
			create l_file.make ("data/output/edges.json")
			l_ok := l_file.set_content ("{%"edges%":[{%"from%":%"doc:README.md%",%"to%":%"class:TOY_BONE%",%"kind%":%"references%",%"why%":%"test merge%"},{%"from%":%"class:NOPE%",%"to%":%"class:TOY_DOG%"}]}")
			assert ("edges_file_written", l_ok)
			create l_facade.make
			l_result := l_facade.annotate ("data/output/edges.json", Out_dir + "/graph.json")
			assert ("merged_one", l_result.has_substring ("Merged 1 edge"))
			assert ("rejected_one", l_result.has_substring ("Rejected"))
			l_loaded := l_facade.load (Out_dir + "/graph.json")
			assert ("reload_ok", l_loaded)
			assert ("merged_edge_present", edge_kind_present (l_facade.graph, "doc:README.md", "class:TOY_BONE", "references"))
		end

feature -- Tests: artifacts

	test_html_self_contained
			-- graph.html embeds data and makes no external requests.
		local
			l_file: SIMPLE_FILE
			l_html: STRING
			l_util: GRAPHIFY_FS
		do
			assert ("built", built_facade.has_graph)
			create l_util.make
			create l_file.make (Out_dir + "/graph.html")
			l_html := l_util.utf8 (l_file.content)
			assert ("has_canvas", l_html.has_substring ("<canvas"))
			assert ("has_data", l_html.has_substring ("class:TOY_DOG"))
			assert ("no_external", not l_html.has_substring ("https://"))
		end

	test_report_sections
			-- GRAPH_REPORT.md carries all required sections.
		local
			l_file: SIMPLE_FILE
			l_text: STRING
			l_util: GRAPHIFY_FS
		do
			assert ("built", built_facade.has_graph)
			create l_util.make
			create l_file.make (Out_dir + "/GRAPH_REPORT.md")
			l_text := l_util.utf8 (l_file.content)
			assert ("summary", l_text.has_substring ("## Summary"))
			assert ("gods", l_text.has_substring ("## God Nodes"))
			assert ("communities", l_text.has_substring ("## Communities"))
			assert ("surprising", l_text.has_substring ("## Surprising Connections"))
			assert ("contracts", l_text.has_substring ("## Contract Coverage"))
			assert ("questions", l_text.has_substring ("## Suggested Questions"))
			assert ("how_to", l_text.has_substring ("## How to Query"))
		end

	test_deep_mode
			-- Deep build adds feature nodes with containment.
		local
			g: GRAPHIFY_GRAPH
		do
			g := deep_facade.graph
			assert ("chew_feature", g.has_node ("feature:TOY_BONE.chew"))
			assert ("feature_contained", edge_kind_present (g, "class:TOY_BONE", "feature:TOY_BONE.chew", "contains"))
			assert ("signature_use", edge_kind_present (g, "feature:TOY_CAT.inspect_bone", "class:TOY_BONE", "uses"))
		end

	test_empty_directory
			-- Building an Eiffel-free directory fails cleanly.
		local
			l_dir: SIMPLE_FILE
			l_facade: SIMPLE_GRAPHIFY
			l_ignored, l_built: BOOLEAN
		do
			create l_dir.make ("data/output/empty-fixture")
			l_ignored := l_dir.create_directory_recursive
			create l_facade.make
			l_built := l_facade.build ("data/output/empty-fixture", "data/output/empty-out", False, True, False)
			assert ("build_fails", not l_built)
			assert ("error_set", not l_facade.last_error.is_empty)
		end

feature {NONE} -- Implementation

	internal_facade: detachable SIMPLE_GRAPHIFY
			-- Cache for `built_facade`.

	internal_deep_facade: detachable SIMPLE_GRAPHIFY
			-- Cache for `deep_facade`.

	edge_kind_present (a_graph: GRAPHIFY_GRAPH; a_from, a_to, a_kind: STRING): BOOLEAN
			-- Does `a_graph` hold a `a_kind` edge `a_from` -> `a_to`?
		do
			across a_graph.edges_from (a_from) as ic_e loop
				if ic_e.to_id.same_string (a_to) and ic_e.kind.same_string (a_kind) then
					Result := True
				end
			end
		end

	without_timestamp (a_json: STRING): STRING
			-- `a_json` with the generated_at line removed.
		local
			l_lines: LIST [STRING]
		do
			create Result.make (a_json.count)
			l_lines := a_json.split ('%N')
			across l_lines as ic_line loop
				if not ic_line.has_substring ("generated_at") then
					Result.append (ic_line)
					Result.append_character ('%N')
				end
			end
		end

end
