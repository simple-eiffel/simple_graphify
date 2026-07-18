note
	description: "[
		Pass 3: graph analysis. Computes degrees, detects communities by
		deterministic synchronous label propagation over topology edges
		(inherits/uses/creates/references/mentions), labels communities from
		majority library membership, ranks god nodes, and surfaces surprising
		cross-community connections.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_ANALYZER

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create analyzer for `a_graph`.
		do
			graph := a_graph
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Analyzed graph.

feature -- Basic operations

	analyze
			-- Run full analysis: degrees, communities, god nodes, surprising links.
		do
			graph.compute_degrees
			detect_communities
			rank_god_nodes
			find_surprising
		end

feature {NONE} -- Communities

	detect_communities
			-- Label propagation over topology edges; results in
			-- `graph.communities` and per-node community ids.
		local
			l_ids: ARRAYED_LIST [STRING]
			l_label_of: HASH_TABLE [INTEGER, STRING]
			l_new_labels: HASH_TABLE [INTEGER, STRING]
			l_round: INTEGER
			l_changed: BOOLEAN
			l_best: INTEGER
		do
			l_ids := graph.sorted_node_ids
			create l_label_of.make (l_ids.count)
			across l_ids as ic_id loop
				l_label_of.force (l_label_of.count + 1, ic_id)
			end
			from
				l_round := 1
				l_changed := True
			until
				l_round > 20 or not l_changed
			loop
				l_changed := False
				create l_new_labels.make (l_ids.count)
				across l_ids as ic_id loop
					l_best := dominant_neighbor_label (ic_id, l_label_of)
					l_new_labels.force (l_best, ic_id)
					if l_label_of.item (ic_id) /= l_best then
						l_changed := True
					end
				end
				l_label_of := l_new_labels
				l_round := l_round + 1
			end
			build_communities (l_ids, l_label_of)
		end

	dominant_neighbor_label (a_id: STRING; a_label_of: HASH_TABLE [INTEGER, STRING]): INTEGER
			-- Most frequent label among topology neighbors of `a_id`;
			-- ties break to the smallest label; own label when isolated.
		local
			l_counts: HASH_TABLE [INTEGER, INTEGER]
			l_neighbors: ARRAYED_LIST [STRING]
			l_label, l_best, l_best_count: INTEGER
		do
			l_neighbors := graph.undirected_neighbors (a_id, True)
			if l_neighbors.is_empty then
				Result := a_label_of.item (a_id)
			else
				create l_counts.make (l_neighbors.count)
				across l_neighbors as ic_n loop
					l_label := a_label_of.item (ic_n)
					if l_counts.has_key (l_label) then
						l_counts.force (l_counts.found_item + 1, l_label)
					else
						l_counts.force (1, l_label)
					end
				end
				l_best := 0
				l_best_count := 0
				from
					l_counts.start
				until
					l_counts.after
				loop
					l_label := l_counts.key_for_iteration
					if l_counts.item_for_iteration > l_best_count
						or (l_counts.item_for_iteration = l_best_count and l_label < l_best)
					then
						l_best := l_label
						l_best_count := l_counts.item_for_iteration
					end
					l_counts.forth
				end
				Result := l_best
			end
		end

	build_communities (a_ids: ARRAYED_LIST [STRING]; a_label_of: HASH_TABLE [INTEGER, STRING])
			-- Group nodes by final label, renumber by descending size, label,
			-- and install into the graph.
		local
			l_groups: HASH_TABLE [ARRAYED_LIST [STRING], INTEGER]
			l_group: ARRAYED_LIST [STRING]
			l_order_keys: ARRAYED_LIST [STRING]
			l_group_by_key: HASH_TABLE [ARRAYED_LIST [STRING], STRING]
			l_key: STRING
			l_community: GRAPHIFY_COMMUNITY
			l_next_id: INTEGER
			l_label_text: STRING
			l_seen_labels: HASH_TABLE [INTEGER, STRING]
		do
			create l_groups.make (32)
			across a_ids as ic_id loop
				if attached l_groups.item (a_label_of.item (ic_id)) as al_group then
					al_group.extend (ic_id)
				else
					create l_group.make (4)
					l_group.extend (ic_id)
					l_groups.put (l_group, a_label_of.item (ic_id))
				end
			end
			create l_order_keys.make (l_groups.count)
			create l_group_by_key.make (l_groups.count)
			from
				l_groups.start
			until
				l_groups.after
			loop
				l_group := l_groups.item_for_iteration
				l_key := padded_number (999999 - l_group.count, 6) + "|" + l_group.first
				l_order_keys.extend (l_key)
				l_group_by_key.force (l_group, l_key)
				l_groups.forth
			end
			l_order_keys := merge_sorted (l_order_keys)
			l_next_id := 0
			create l_seen_labels.make (l_order_keys.count)
			across l_order_keys as ic_key loop
				if attached l_group_by_key.item (ic_key) as al_group then
					l_next_id := l_next_id + 1
					l_label_text := community_label_for (al_group)
					if l_seen_labels.has_key (l_label_text) then
						l_seen_labels.force (l_seen_labels.found_item + 1, l_label_text)
						l_label_text := l_label_text + " #" + l_seen_labels.found_item.out
					else
						l_seen_labels.force (1, l_label_text)
					end
					create l_community.make (l_next_id, l_label_text)
					across al_group as ic_member loop
						l_community.add_member (ic_member)
						if attached graph.node_by_id (ic_member) as al_node then
							al_node.set_community (l_next_id)
						end
					end
					graph.add_community (l_community)
				end
			end
		end

	community_label_for (a_members: ARRAYED_LIST [STRING]): STRING
			-- Majority library label among members, else highest-degree member + " group".
		local
			l_lib_counts: HASH_TABLE [INTEGER, STRING]
			l_membership: HASH_TABLE [STRING, STRING]
			l_best_label: STRING
			l_best_count: INTEGER
			l_best_degree: INTEGER
			l_best_node: detachable GRAPHIFY_NODE
		do
			l_membership := library_membership
			create l_lib_counts.make (8)
			across a_members as ic_m loop
				if attached l_membership.item (ic_m) as al_lib then
					if l_lib_counts.has_key (al_lib) then
						l_lib_counts.force (l_lib_counts.found_item + 1, al_lib)
					else
						l_lib_counts.force (1, al_lib)
					end
				end
			end
			create l_best_label.make_empty
			l_best_count := 0
			from
				l_lib_counts.start
			until
				l_lib_counts.after
			loop
				if l_lib_counts.item_for_iteration > l_best_count
					or (l_lib_counts.item_for_iteration = l_best_count
						and then l_lib_counts.key_for_iteration < l_best_label)
				then
					l_best_label := l_lib_counts.key_for_iteration
					l_best_count := l_lib_counts.item_for_iteration
				end
				l_lib_counts.forth
			end
			if not l_best_label.is_empty then
				Result := l_best_label
			else
				l_best_degree := -1
				across a_members as ic_m loop
					if attached graph.node_by_id (ic_m) as al_node then
						if al_node.degree > l_best_degree
							or (al_node.degree = l_best_degree and then (l_best_node = Void or else al_node.id < l_best_node.id))
						then
							l_best_degree := al_node.degree
							l_best_node := al_node
						end
					end
				end
				if attached l_best_node as al_b then
					Result := al_b.label + " group"
				else
					Result := "group"
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	library_membership: HASH_TABLE [STRING, STRING]
			-- Library label per node id, resolved through contains edges
			-- (library -> cluster -> class -> feature).
		local
			l_pending: ARRAYED_LIST [STRING]
			l_next: ARRAYED_LIST [STRING]
			l_rounds: INTEGER
		do
			create Result.make (graph.node_count)
			create l_pending.make (8)
			across graph.nodes as ic_n loop
				if ic_n.kind.same_string ("library") and not ic_n.has_flag ("external") then
					Result.force (ic_n.label, ic_n.id)
					l_pending.extend (ic_n.id)
				end
			end
			from
				l_rounds := 1
			until
				l_pending.is_empty or l_rounds > 5
			loop
				create l_next.make (l_pending.count)
				across l_pending as ic_id loop
					across graph.edges_from (ic_id) as ic_e loop
						if ic_e.kind.same_string ("contains") and then not Result.has (ic_e.to_id) then
							if attached Result.item (ic_id) as al_lib then
								Result.force (al_lib, ic_e.to_id)
								l_next.extend (ic_e.to_id)
							end
						end
					end
				end
				l_pending := l_next
				l_rounds := l_rounds + 1
			end
		end

feature {NONE} -- God nodes and surprises

	rank_god_nodes
			-- Top 10 nodes by degree (excluding documents and rationale tags).
		local
			l_keys: ARRAYED_LIST [STRING]
			l_id_by_key: HASH_TABLE [STRING, STRING]
			l_key: STRING
			l_result: ARRAYED_LIST [STRING]
		do
			create l_keys.make (graph.node_count)
			create l_id_by_key.make (graph.node_count)
			across graph.nodes as ic_n loop
				if not ic_n.kind.same_string ("document") and not ic_n.kind.same_string ("rationale") then
					l_key := padded_number (999999 - ic_n.degree, 6) + "|" + ic_n.id
					l_keys.extend (l_key)
					l_id_by_key.force (ic_n.id, l_key)
				end
			end
			l_keys := merge_sorted (l_keys)
			create l_result.make (10)
			across l_keys as ic_key loop
				if l_result.count < 10 and then attached l_id_by_key.item (ic_key) as al_id then
					l_result.extend (al_id)
				end
			end
			graph.set_god_nodes (l_result)
		end

	find_surprising
			-- Top 10 cross-community links between otherwise-peripheral nodes.
		local
			l_keys: ARRAYED_LIST [STRING]
			l_edge_by_key: HASH_TABLE [GRAPHIFY_EDGE, STRING]
			l_key: STRING
			l_from, l_to: detachable GRAPHIFY_NODE
			l_score, l_added: INTEGER
			l_doc_rank: STRING
		do
			create l_keys.make (32)
			create l_edge_by_key.make (32)
			across graph.sorted_edges as ic_e loop
				if graph.is_topology_kind (ic_e.kind) and not ic_e.kind.same_string ("mentions") then
					l_from := graph.node_by_id (ic_e.from_id)
					l_to := graph.node_by_id (ic_e.to_id)
					if attached l_from as al_f and attached l_to as al_t then
						if al_f.community /= al_t.community and al_f.community > 0 and al_t.community > 0 then
							l_score := al_f.degree.min (al_t.degree)
							if al_f.kind.same_string ("document") or al_t.kind.same_string ("document") then
								l_doc_rank := "0"
							else
								l_doc_rank := "1"
							end
							l_key := l_doc_rank + "|" + padded_number (l_score, 6) + "|" + ic_e.key
							l_keys.extend (l_key)
							l_edge_by_key.force (ic_e, l_key)
						end
					end
				end
			end
			l_keys := merge_sorted (l_keys)
			l_added := 0
			across l_keys as ic_key loop
				if l_added < 10 and then attached l_edge_by_key.item (ic_key) as al_edge then
					l_added := l_added + 1
					if attached graph.node_by_id (al_edge.from_id) as al_f and attached graph.node_by_id (al_edge.to_id) as al_t then
						graph.add_surprising (al_edge,
							"bridges %"" + graph.community_label (al_f.community)
							+ "%" and %"" + graph.community_label (al_t.community) + "%"")
					end
				end
			end
		end

invariant
	graph_attached: graph /= Void

end
