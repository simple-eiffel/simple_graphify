note
	description: "[
		The knowledge graph: nodes keyed by id, merged typed edges, adjacency,
		communities, god nodes, and surprising connections. Deterministic:
		serialization order is fully defined by node/edge identities.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_GRAPH

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Create empty graph.
		do
			create nodes.make (200)
			create edges.make (500)
			create edge_by_key.make (500)
			create out_edges.make (200)
			create in_edges.make (200)
			create communities.make (10)
			create god_node_ids.make (10)
			create surprising.make (10)
			create warnings.make (5)
			root_path := ""
			mode := "standard"
			generated_at := ""
		end

feature -- Access

	nodes: HASH_TABLE [GRAPHIFY_NODE, STRING]
			-- Nodes keyed by id.

	edges: ARRAYED_LIST [GRAPHIFY_EDGE]
			-- All edges (unique per (from, to, kind); duplicates merged into weight).

	communities: ARRAYED_LIST [GRAPHIFY_COMMUNITY]
			-- Detected communities, ordered by id.

	god_node_ids: ARRAYED_LIST [STRING]
			-- Highest-degree hub node ids, ranked.

	surprising: ARRAYED_LIST [TUPLE [edge: GRAPHIFY_EDGE; reason: STRING]]
			-- Cross-community connections worth attention.

	warnings: ARRAYED_LIST [STRING]
			-- Non-fatal problems collected during a build.

	root_path: STRING
			-- Absolute root the graph was built from ('/' separators).

	mode: STRING
			-- "standard" or "deep".

	generated_at: STRING
			-- ISO-8601 build timestamp.

	files_scanned: INTEGER
			-- Total files examined.

	classes_scanned: INTEGER
			-- Eiffel classes contributing nodes.

	documents_scanned: INTEGER
			-- Markdown documents contributing nodes.

	node_by_id (a_id: STRING): detachable GRAPHIFY_NODE
			-- Node with id `a_id`, if present.
		require
			id_not_empty: not a_id.is_empty
		do
			Result := nodes.item (a_id)
		end

	has_node (a_id: STRING): BOOLEAN
			-- Is a node with id `a_id` present?
		require
			id_not_empty: not a_id.is_empty
		do
			Result := nodes.has (a_id)
		end

	node_count: INTEGER
			-- Number of nodes.
		do
			Result := nodes.count
		end

	edge_count: INTEGER
			-- Number of (merged) edges.
		do
			Result := edges.count
		end

	edges_from (a_id: STRING): ARRAYED_LIST [GRAPHIFY_EDGE]
			-- Outgoing edges of node `a_id`.
		require
			id_not_empty: not a_id.is_empty
		do
			if attached out_edges.item (a_id) as al_list then
				Result := al_list
			else
				create Result.make (0)
			end
		ensure
			result_attached: Result /= Void
		end

	edges_to (a_id: STRING): ARRAYED_LIST [GRAPHIFY_EDGE]
			-- Incoming edges of node `a_id`.
		require
			id_not_empty: not a_id.is_empty
		do
			if attached in_edges.item (a_id) as al_list then
				Result := al_list
			else
				create Result.make (0)
			end
		ensure
			result_attached: Result /= Void
		end

	sorted_node_ids: ARRAYED_LIST [STRING]
			-- All node ids, ascending.
		local
			l_ids: ARRAYED_LIST [STRING]
		do
			create l_ids.make (nodes.count)
			across nodes as ic_n loop
				l_ids.extend (ic_n.id)
			end
			Result := merge_sorted (l_ids)
		ensure
			complete: Result.count = nodes.count
		end

	sorted_edges: ARRAYED_LIST [GRAPHIFY_EDGE]
			-- All edges ordered by (from, to, kind).
		local
			l_keys: ARRAYED_LIST [STRING]
		do
			create l_keys.make (edges.count)
			across edges as ic_e loop
				l_keys.extend (ic_e.key)
			end
			l_keys := merge_sorted (l_keys)
			create Result.make (l_keys.count)
			across l_keys as ic_k loop
				if attached edge_by_key.item (ic_k) as al_edge then
					Result.extend (al_edge)
				end
			end
		ensure
			complete: Result.count = edges.count
		end

	community_of (a_id: INTEGER): detachable GRAPHIFY_COMMUNITY
			-- Community with id `a_id`, if any.
		do
			across communities as ic_c loop
				if ic_c.id = a_id then
					Result := ic_c
				end
			end
		end

	community_label (a_id: INTEGER): STRING
			-- Label of community `a_id`; "-" when unknown.
		do
			if attached community_of (a_id) as al_c then
				Result := al_c.label
			else
				Result := "-"
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Modification

	add_node (a_node: GRAPHIFY_NODE)
			-- Register `a_node`; first registration of an id wins.
		do
			if not nodes.has (a_node.id) then
				nodes.put (a_node, a_node.id)
			end
		ensure
			present: has_node (a_node.id)
		end

	add_edge (a_edge: GRAPHIFY_EDGE)
			-- Register `a_edge`; a duplicate (from, to, kind) merges its weight
			-- into the existing edge and keeps the earliest line.
		local
			l_key: STRING
		do
			l_key := a_edge.key
			if attached edge_by_key.item (l_key) as al_existing then
				al_existing.set_weight (al_existing.weight + a_edge.weight)
				if al_existing.line = 0 or (a_edge.line > 0 and a_edge.line < al_existing.line) then
					al_existing.set_line (a_edge.line)
				end
			else
				edges.extend (a_edge)
				edge_by_key.put (a_edge, l_key)
				adjacency_add (out_edges, a_edge.from_id, a_edge)
				adjacency_add (in_edges, a_edge.to_id, a_edge)
			end
		ensure
			registered: edge_by_key.has (a_edge.key)
		end

	connect (a_from, a_to, a_kind, a_confidence: STRING; a_line: INTEGER; a_why: STRING)
			-- Convenience: build and add an edge when both differ.
		require
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
			kind_not_empty: not a_kind.is_empty
		local
			l_edge: GRAPHIFY_EDGE
		do
			if not a_from.same_string (a_to) then
				create l_edge.make (a_from, a_to, a_kind, a_confidence)
				l_edge.set_line (a_line)
				l_edge.set_why (a_why)
				add_edge (l_edge)
			end
		end

	add_community (a_community: GRAPHIFY_COMMUNITY)
			-- Register `a_community`.
		do
			communities.extend (a_community)
		ensure
			one_more: communities.count = old communities.count + 1
		end

	add_warning (a_text: STRING)
			-- Record non-fatal problem.
		require
			text_not_empty: not a_text.is_empty
		do
			warnings.extend (a_text)
		end

	set_meta (a_root, a_mode, a_generated_at: STRING)
			-- Set build metadata.
		do
			root_path := a_root
			mode := a_mode
			generated_at := a_generated_at
		end

	set_scan_counts (a_files, a_classes, a_documents: INTEGER)
			-- Set scan statistics.
		require
			non_negative: a_files >= 0 and a_classes >= 0 and a_documents >= 0
		do
			files_scanned := a_files
			classes_scanned := a_classes
			documents_scanned := a_documents
		end

	set_god_nodes (a_ids: ARRAYED_LIST [STRING])
			-- Set ranked god-node list.
		do
			god_node_ids := a_ids
		end

	add_surprising (a_edge: GRAPHIFY_EDGE; a_reason: STRING)
			-- Record a surprising cross-community connection.
		do
			surprising.extend ([a_edge, a_reason])
		end

feature -- Analysis support

	compute_degrees
			-- Set every node's degree = distinct out + in edges.
		do
			across nodes as ic_n loop
				ic_n.set_degree (edges_from (ic_n.id).count + edges_to (ic_n.id).count)
			end
		end

	undirected_neighbors (a_id: STRING; a_topology_only: BOOLEAN): ARRAYED_LIST [STRING]
			-- Neighbor ids of `a_id` over all edges; when `a_topology_only`,
			-- containment/dependency edges are excluded (community detection view).
		require
			id_not_empty: not a_id.is_empty
		do
			create Result.make (8)
			across edges_from (a_id) as ic_e loop
				if not a_topology_only or else is_topology_kind (ic_e.kind) then
					Result.extend (ic_e.to_id)
				end
			end
			across edges_to (a_id) as ic_e loop
				if not a_topology_only or else is_topology_kind (ic_e.kind) then
					Result.extend (ic_e.from_id)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	shortest_path (a_from, a_to: STRING): ARRAYED_LIST [STRING]
			-- Node ids along an undirected shortest path from `a_from` to `a_to`;
			-- empty when disconnected.
		require
			from_present: has_node (a_from)
			to_present: has_node (a_to)
		local
			l_graph: SIMPLE_GRAPH [STRING]
			l_int_of: HASH_TABLE [INTEGER, STRING]
			l_id_of: HASH_TABLE [STRING, INTEGER]
			l_int: INTEGER
			l_path: ARRAYED_LIST [INTEGER]
		do
			create l_graph.make
			create l_int_of.make (nodes.count)
			create l_id_of.make (nodes.count)
			across sorted_node_ids as ic_id loop
				l_int := l_graph.add_node (ic_id)
				l_int_of.put (l_int, ic_id)
				l_id_of.put (ic_id, l_int)
			end
			across edges as ic_e loop
				if attached l_int_of.item (ic_e.from_id) as al_f and attached l_int_of.item (ic_e.to_id) as al_t then
					if not l_graph.has_edge (al_f, al_t) then
						l_graph.add_edge (al_f, al_t)
					end
				end
			end
			create Result.make (8)
			if attached l_int_of.item (a_from) as al_from and attached l_int_of.item (a_to) as al_to then
				l_path := l_graph.dijkstra (al_from, al_to)
				across l_path as ic_i loop
					if attached l_id_of.item (ic_i) as al_id then
						Result.extend (al_id)
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

	edge_between (a_from, a_to: STRING): detachable GRAPHIFY_EDGE
			-- Any edge connecting `a_from` and `a_to` in either direction
			-- (preferring the from->to direction).
		require
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
		do
			across edges_from (a_from) as ic_e loop
				if Result = Void and then ic_e.to_id.same_string (a_to) then
					Result := ic_e
				end
			end
			if Result = Void then
				across edges_from (a_to) as ic_e loop
					if Result = Void and then ic_e.to_id.same_string (a_from) then
						Result := ic_e
					end
				end
			end
		end

	is_topology_kind (a_kind: STRING): BOOLEAN
			-- Does `a_kind` participate in community detection?
		do
			Result := a_kind.same_string ("inherits")
				or a_kind.same_string ("uses")
				or a_kind.same_string ("creates")
				or a_kind.same_string ("references")
				or a_kind.same_string ("mentions")
		end

feature {NONE} -- Implementation

	edge_by_key: HASH_TABLE [GRAPHIFY_EDGE, STRING]
			-- Edges keyed by (from|to|kind) for merging.

	out_edges: HASH_TABLE [ARRAYED_LIST [GRAPHIFY_EDGE], STRING]
			-- Outgoing adjacency.

	in_edges: HASH_TABLE [ARRAYED_LIST [GRAPHIFY_EDGE], STRING]
			-- Incoming adjacency.

	adjacency_add (a_table: HASH_TABLE [ARRAYED_LIST [GRAPHIFY_EDGE], STRING]; a_id: STRING; a_edge: GRAPHIFY_EDGE)
			-- Append `a_edge` to `a_table [a_id]`.
		local
			l_list: ARRAYED_LIST [GRAPHIFY_EDGE]
		do
			if attached a_table.item (a_id) as al_list then
				al_list.extend (a_edge)
			else
				create l_list.make (4)
				l_list.extend (a_edge)
				a_table.put (l_list, a_id)
			end
		end

invariant
	edges_indexed: edges.count = edge_by_key.count

end
