note
	description: "GRAPH_REPORT.md generator: summary, god nodes, communities, surprising connections, contract coverage, suggested questions"
	author: "Larry Rix"

class
	GRAPHIFY_REPORT

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create report generator over `a_graph`.
		do
			graph := a_graph
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Reported graph.

feature -- Basic operations

	report_text: STRING
			-- Full GRAPH_REPORT.md content.
		local
			l_root_name: STRING
		do
			l_root_name := path_base_stem (graph.root_path)
			if l_root_name.is_empty then
				l_root_name := graph.root_path
			end
			create Result.make (8192)
			Result.append ("# Knowledge Graph Report - " + l_root_name + "%N%N")
			Result.append ("Generated: " + graph.generated_at + " - Mode: " + graph.mode
				+ " - simple_graphify 1.0.0%N%N")
			append_summary (Result)
			append_god_nodes (Result)
			append_communities (Result)
			append_surprising (Result)
			append_contract_coverage (Result)
			append_suggested_questions (Result)
			append_how_to_query (Result)
			if not graph.warnings.is_empty then
				Result.append ("%N## Build warnings%N%N")
				across graph.warnings as ic_w loop
					Result.append ("- " + ic_w + "%N")
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Sections

	append_summary (a_target: STRING)
			-- Summary table.
		do
			a_target.append ("## Summary%N%N")
			a_target.append ("| Metric | Value |%N|---|---|%N")
			a_target.append ("| Files scanned | " + graph.files_scanned.out + " |%N")
			a_target.append ("| Eiffel classes | " + graph.classes_scanned.out + " |%N")
			a_target.append ("| Documents | " + graph.documents_scanned.out + " |%N")
			a_target.append ("| Nodes | " + graph.node_count.out + " |%N")
			a_target.append ("| Edges | " + graph.edge_count.out + " |%N")
			a_target.append ("| Communities | " + graph.communities.count.out + " |%N%N")
		end

	append_god_nodes (a_target: STRING)
			-- God node ranking.
		local
			l_rank: INTEGER
		do
			a_target.append ("## God Nodes%N%N")
			a_target.append ("Most-connected concepts; the integration points of this codebase.%N%N")
			l_rank := 0
			across graph.god_node_ids as ic_id loop
				if attached graph.node_by_id (ic_id) as al_node then
					l_rank := l_rank + 1
					a_target.append (l_rank.out + ". **" + al_node.label + "** (" + al_node.kind
						+ ", degree " + al_node.degree.out + ")")
					if not al_node.description.is_empty then
						a_target.append (" - " + al_node.description)
					end
					a_target.append ("%N")
				end
			end
			a_target.append ("%N")
		end

	append_communities (a_target: STRING)
			-- Community table.
		local
			l_sample: STRING
			l_count: INTEGER
		do
			a_target.append ("## Communities%N%N")
			a_target.append ("| Id | Label | Size | Sample members |%N|---|---|---|---|%N")
			across graph.communities as ic_c loop
				create l_sample.make (80)
				l_count := 0
				across merge_sorted (ic_c.members) as ic_m loop
					if l_count < 4 then
						if l_count > 0 then
							l_sample.append (", ")
						end
						l_sample.append (short_label (ic_m))
						l_count := l_count + 1
					end
				end
				a_target.append ("| " + ic_c.id.out + " | " + ic_c.label + " | "
					+ ic_c.size.out + " | " + l_sample + " |%N")
			end
			a_target.append ("%N")
		end

	append_surprising (a_target: STRING)
			-- Surprising connections list.
		do
			a_target.append ("## Surprising Connections%N%N")
			if graph.surprising.is_empty then
				a_target.append ("(none detected)%N%N")
			else
				across graph.surprising as ic_s loop
					a_target.append ("- " + short_label (ic_s.edge.from_id) + " --" + ic_s.edge.kind
						+ "--> " + short_label (ic_s.edge.to_id) + " : " + ic_s.reason + "%N")
				end
				a_target.append ("%N")
			end
		end

	append_contract_coverage (a_target: STRING)
			-- Eiffel-specific Design-by-Contract coverage section.
		local
			l_classes, l_contracted: INTEGER
			l_top_keys: ARRAYED_LIST [STRING]
			l_free: ARRAYED_LIST [STRING]
			l_contracts: INTEGER
			l_pct: INTEGER
			l_shown: INTEGER
		do
			a_target.append ("## Contract Coverage (Design by Contract)%N%N")
			create l_top_keys.make (32)
			create l_free.make (16)
			across graph.nodes as ic_n loop
				if ic_n.kind.same_string ("class") and not ic_n.has_flag ("external") then
					l_classes := l_classes + 1
					l_contracts := ic_n.metric ("preconditions") + ic_n.metric ("postconditions")
					if l_contracts > 0 then
						l_contracted := l_contracted + 1
						l_top_keys.extend (padded_number (999999 - l_contracts, 6) + "|" + ic_n.label)
					else
						l_free.extend (ic_n.label)
					end
				end
			end
			if l_classes > 0 then
				l_pct := (l_contracted * 100) // l_classes
				a_target.append ("- Classes with contracts: " + l_contracted.out + "/" + l_classes.out
					+ " (" + l_pct.out + "%%)%N%N")
				l_top_keys := merge_sorted (l_top_keys)
				a_target.append ("Top contracted classes:%N%N")
				l_shown := 0
				across l_top_keys as ic_key loop
					if l_shown < 10 then
						l_shown := l_shown + 1
						a_target.append ("- " + ic_key.substring (8, ic_key.count)
							+ " (" + (999999 - ic_key.substring (1, 6).to_integer).out + " contract clauses)%N")
					end
				end
				if not l_free.is_empty then
					l_free := merge_sorted (l_free)
					a_target.append ("%NContract-free classes (candidates for hardening):%N%N")
					l_shown := 0
					across l_free as ic_name loop
						if l_shown < 15 then
							l_shown := l_shown + 1
							a_target.append ("- " + ic_name + "%N")
						end
					end
					if l_free.count > 15 then
						a_target.append ("- ... and " + (l_free.count - 15).out + " more%N")
					end
				end
			else
				a_target.append ("(no classes scanned)%N")
			end
			a_target.append ("%N")
		end

	append_suggested_questions (a_target: STRING)
			-- Generated starter questions.
		local
			l_count: INTEGER
		do
			a_target.append ("## Suggested Questions%N%N")
			l_count := 0
			across graph.god_node_ids as ic_id loop
				if l_count < 3 and then attached graph.node_by_id (ic_id) as al_node then
					l_count := l_count + 1
					a_target.append ("- What depends on " + al_node.label + "?%N")
				end
			end
			if graph.communities.count >= 2 and then attached graph.communities.first as al_first then
				across graph.communities as ic_c loop
					if l_count < 5 and ic_c.id /= al_first.id then
						l_count := l_count + 1
						a_target.append ("- How do %"" + al_first.label + "%" and %"" + ic_c.label + "%" connect?%N")
					end
				end
			end
			a_target.append ("- Which classes have no contracts yet?%N%N")
		end

	append_how_to_query (a_target: STRING)
			-- CLI cheat sheet.
		do
			a_target.append ("## How to Query%N%N")
			a_target.append ("```%N")
			a_target.append ("simple_graphify query %"how does X work%"   # scoped subgraph%N")
			a_target.append ("simple_graphify explain CLASS_NAME        # node + all connections%N")
			a_target.append ("simple_graphify path CLASS_A CLASS_B      # shortest connection%N")
			a_target.append ("simple_graphify stats                     # graph overview%N")
			a_target.append ("```%N")
		end

	short_label (a_id: STRING): STRING
			-- `a_id` without kind prefix.
		local
			l_colon: INTEGER
		do
			l_colon := a_id.index_of (':', 1)
			if l_colon > 0 and l_colon < a_id.count then
				Result := a_id.substring (l_colon + 1, a_id.count)
			else
				Result := a_id
			end
		ensure
			result_attached: Result /= Void
		end

invariant
	graph_attached: graph /= Void

end
