note
	description: "Test application for simple_graphify"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Run tests.
		local
			tests: LIB_TESTS
		do
			create tests
			io.put_string ("simple_graphify test runner%N")
			io.put_string ("====================================%N%N")

			passed := 0
			failed := 0

			io.put_string ("Build Tests%N")
			io.put_string ("-----------%N")
			run_test (agent tests.test_build_succeeds, "test_build_succeeds")
			run_test (agent tests.test_library_and_clusters, "test_library_and_clusters")
			run_test (agent tests.test_class_nodes, "test_class_nodes")
			run_test (agent tests.test_inherits_edges, "test_inherits_edges")
			run_test (agent tests.test_creates_edge, "test_creates_edge")
			run_test (agent tests.test_uses_edges, "test_uses_edges")
			run_test (agent tests.test_mentions_edge, "test_mentions_edge")
			run_test (agent tests.test_rationale_tags, "test_rationale_tags")
			run_test (agent tests.test_metrics, "test_metrics")
			run_test (agent tests.test_doc_nodes, "test_doc_nodes")

			io.put_string ("%NAnalysis Tests%N")
			io.put_string ("--------------%N")
			run_test (agent tests.test_degrees_and_god_nodes, "test_degrees_and_god_nodes")
			run_test (agent tests.test_communities_cover_all, "test_communities_cover_all")
			run_test (agent tests.test_determinism, "test_determinism")
			run_test (agent tests.test_json_roundtrip, "test_json_roundtrip")

			io.put_string ("%NQuery Tests%N")
			io.put_string ("-----------%N")
			run_test (agent tests.test_query_hits, "test_query_hits")
			run_test (agent tests.test_query_miss, "test_query_miss")
			run_test (agent tests.test_explain, "test_explain")
			run_test (agent tests.test_path, "test_path")
			run_test (agent tests.test_stats, "test_stats")
			run_test (agent tests.test_annotate, "test_annotate")

			io.put_string ("%NArtifact Tests%N")
			io.put_string ("--------------%N")
			run_test (agent tests.test_html_self_contained, "test_html_self_contained")
			run_test (agent tests.test_report_sections, "test_report_sections")
			run_test (agent tests.test_deep_mode, "test_deep_mode")
			run_test (agent tests.test_empty_directory, "test_empty_directory")

			io.put_string ("%N====================================%N")
			io.put_string ("Results: " + passed.out + " passed, " + failed.out + " failed%N")
			if failed > 0 then
				io.put_string ("TESTS FAILED%N")
			else
				io.put_string ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Implementation

	passed: INTEGER
	failed: INTEGER

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run a single test and update counters.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				io.put_string ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			io.put_string ("  FAIL: " + a_name + "%N")
			if attached (create {EXCEPTION_MANAGER_FACTORY}).exception_manager.last_exception as al_ex then
				if attached al_ex.description as al_desc then
					io.put_string ("    reason: " + al_desc.to_string_8 + "%N")
				end
				if attached al_ex.trace as al_trace then
					io.put_string (al_trace.to_string_8 + "%N")
				end
			end
			failed := failed + 1
			l_retried := True
			retry
		end

end
