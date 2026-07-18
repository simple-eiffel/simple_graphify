note
	description: "[
		graph.json persistence. Serialization is hand-emitted with stable
		ordering (byte-identical for identical inputs, apart from the
		generated_at header). Loading uses simple_json.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_JSON_IO

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Create serializer.
		do
			last_error := ""
		end

feature -- Access

	last_error: STRING
			-- Problem from the last `loaded` call; empty when none.

	Generator_name: STRING = "simple_graphify 1.0.0"
			-- Generator identification written into graph.json.

feature -- Serialization

	serialized (a_graph: GRAPHIFY_GRAPH): STRING
			-- Full graph.json text for `a_graph`.
		local
			l_first: BOOLEAN
		do
			create Result.make (65536)
			Result.append ("{%N")
			Result.append ("  %"schema_version%": %"1.0%",%N")
			Result.append ("  %"generator%": %"" + Generator_name + "%",%N")
			Result.append ("  %"root%": %"" + json_escaped (a_graph.root_path) + "%",%N")
			Result.append ("  %"generated_at%": %"" + json_escaped (a_graph.generated_at) + "%",%N")
			Result.append ("  %"mode%": %"" + json_escaped (a_graph.mode) + "%",%N")
			Result.append ("  %"stats%": { %"nodes%": " + a_graph.node_count.out
				+ ", %"edges%": " + a_graph.edge_count.out
				+ ", %"communities%": " + a_graph.communities.count.out
				+ ", %"files_scanned%": " + a_graph.files_scanned.out
				+ ", %"classes%": " + a_graph.classes_scanned.out
				+ ", %"documents%": " + a_graph.documents_scanned.out + " },%N")
			Result.append ("  %"nodes%": [%N")
			l_first := True
			across a_graph.sorted_node_ids as ic_id loop
				if attached a_graph.node_by_id (ic_id) as al_node then
					if not l_first then
						Result.append (",%N")
					end
					l_first := False
					Result.append ("    " + node_json (al_node))
				end
			end
			Result.append ("%N  ],%N")
			Result.append ("  %"edges%": [%N")
			l_first := True
			across a_graph.sorted_edges as ic_e loop
				if not l_first then
					Result.append (",%N")
				end
				l_first := False
				Result.append ("    " + edge_json (ic_e))
			end
			Result.append ("%N  ],%N")
			Result.append ("  %"communities%": [%N")
			l_first := True
			across a_graph.communities as ic_c loop
				if not l_first then
					Result.append (",%N")
				end
				l_first := False
				Result.append ("    " + community_json (ic_c))
			end
			Result.append ("%N  ],%N")
			Result.append ("  %"god_nodes%": " + string_array_json (a_graph.god_node_ids) + ",%N")
			Result.append ("  %"surprising%": [%N")
			l_first := True
			across a_graph.surprising as ic_s loop
				if not l_first then
					Result.append (",%N")
				end
				l_first := False
				Result.append ("    { %"from%": %"" + json_escaped (ic_s.edge.from_id)
					+ "%", %"to%": %"" + json_escaped (ic_s.edge.to_id)
					+ "%", %"kind%": %"" + json_escaped (ic_s.edge.kind)
					+ "%", %"reason%": %"" + json_escaped (ic_s.reason) + "%" }")
			end
			Result.append ("%N  ]%N")
			Result.append ("}%N")
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Loading

	loaded (a_json_text: STRING): detachable GRAPHIFY_GRAPH
			-- Graph reconstructed from `a_json_text`; Void (with `last_error`) on failure.
		local
			l_quick: SIMPLE_JSON_QUICK
			l_graph: GRAPHIFY_GRAPH
		do
			last_error := ""
			if a_json_text.is_empty then
				last_error := "Empty graph file"
			else
				create l_quick.make
				if attached l_quick.parse_object (a_json_text) as al_root then
					create l_graph.make
					load_meta (l_graph, al_root)
					if attached al_root.array_item ("nodes") as al_nodes then
						load_nodes (l_graph, al_nodes)
					end
					if attached al_root.array_item ("edges") as al_edges then
						load_edges (l_graph, al_edges)
					end
					if attached al_root.array_item ("communities") as al_comms then
						load_communities (l_graph, al_comms)
					end
					if attached al_root.array_item ("god_nodes") as al_gods then
						load_god_nodes (l_graph, al_gods)
					end
					if attached al_root.array_item ("surprising") as al_surp then
						load_surprising (l_graph, al_surp)
					end
					Result := l_graph
				else
					last_error := "Invalid JSON in graph file"
				end
			end
		ensure
			error_on_failure: Result = Void implies not last_error.is_empty
		end

feature {NONE} -- Serialization parts

	node_json (a_node: GRAPHIFY_NODE): STRING
			-- One-line JSON object for `a_node`.
		local
			l_first: BOOLEAN
			l_keys: ARRAYED_LIST [STRING]
		do
			create Result.make (200)
			Result.append ("{ %"id%": %"" + json_escaped (a_node.id)
				+ "%", %"kind%": %"" + json_escaped (a_node.kind)
				+ "%", %"label%": %"" + json_escaped (a_node.label) + "%"")
			if not a_node.file_path.is_empty then
				Result.append (", %"file%": %"" + json_escaped (a_node.file_path) + "%"")
			end
			if a_node.line > 0 then
				Result.append (", %"line%": " + a_node.line.out)
			end
			Result.append (", %"community%": " + a_node.community.out)
			Result.append (", %"degree%": " + a_node.degree.out)
			if not a_node.flags.is_empty then
				Result.append (", %"flags%": " + string_array_json (a_node.flags))
			end
			if not a_node.description.is_empty then
				Result.append (", %"description%": %"" + json_escaped (a_node.description) + "%"")
			end
			if not a_node.metrics.is_empty then
				Result.append (", %"metrics%": { ")
				create l_keys.make (a_node.metrics.count)
				from
					a_node.metrics.start
				until
					a_node.metrics.after
				loop
					l_keys.extend (a_node.metrics.key_for_iteration)
					a_node.metrics.forth
				end
				l_keys := merge_sorted (l_keys)
				l_first := True
				across l_keys as ic_k loop
					if not l_first then
						Result.append (", ")
					end
					l_first := False
					Result.append ("%"" + json_escaped (ic_k) + "%": " + a_node.metric (ic_k).out)
				end
				Result.append (" }")
			end
			Result.append (" }")
		end

	edge_json (a_edge: GRAPHIFY_EDGE): STRING
			-- One-line JSON object for `a_edge`.
		do
			create Result.make (160)
			Result.append ("{ %"from%": %"" + json_escaped (a_edge.from_id)
				+ "%", %"to%": %"" + json_escaped (a_edge.to_id)
				+ "%", %"kind%": %"" + json_escaped (a_edge.kind)
				+ "%", %"confidence%": %"" + json_escaped (a_edge.confidence)
				+ "%", %"weight%": " + a_edge.weight.out)
			if a_edge.line > 0 then
				Result.append (", %"line%": " + a_edge.line.out)
			end
			if not a_edge.why.is_empty then
				Result.append (", %"why%": %"" + json_escaped (a_edge.why) + "%"")
			end
			Result.append (" }")
		end

	community_json (a_community: GRAPHIFY_COMMUNITY): STRING
			-- One-line JSON object for `a_community` (member sample <= 8).
		local
			l_sample: ARRAYED_LIST [STRING]
			l_sorted: ARRAYED_LIST [STRING]
		do
			l_sorted := merge_sorted (a_community.members)
			create l_sample.make (8)
			across l_sorted as ic_m loop
				if l_sample.count < 8 then
					l_sample.extend (ic_m)
				end
			end
			create Result.make (200)
			Result.append ("{ %"id%": " + a_community.id.out
				+ ", %"label%": %"" + json_escaped (a_community.label)
				+ "%", %"size%": " + a_community.size.out
				+ ", %"members_sample%": " + string_array_json (l_sample) + " }")
		end

	string_array_json (a_list: ARRAYED_LIST [STRING]): STRING
			-- JSON array of strings.
		local
			l_first: BOOLEAN
		do
			create Result.make (64)
			Result.append ("[")
			l_first := True
			across a_list as ic_s loop
				if not l_first then
					Result.append (", ")
				end
				l_first := False
				Result.append ("%"" + json_escaped (ic_s) + "%"")
			end
			Result.append ("]")
		end

feature {NONE} -- Loading parts

	load_meta (a_graph: GRAPHIFY_GRAPH; a_root: SIMPLE_JSON_OBJECT)
			-- Restore header metadata.
		local
			l_root, l_mode, l_at: STRING
		do
			l_root := string_field (a_root, "root")
			l_mode := string_field (a_root, "mode")
			l_at := string_field (a_root, "generated_at")
			if l_mode.is_empty then
				l_mode := "standard"
			end
			a_graph.set_meta (l_root, l_mode, l_at)
			if attached a_root.object_item ("stats") as al_stats then
				a_graph.set_scan_counts (
					al_stats.integer_item ("files_scanned").to_integer_32.max (0),
					al_stats.integer_item ("classes").to_integer_32.max (0),
					al_stats.integer_item ("documents").to_integer_32.max (0))
			end
		end

	load_nodes (a_graph: GRAPHIFY_GRAPH; a_nodes: SIMPLE_JSON_ARRAY)
			-- Restore nodes.
		local
			i: INTEGER
			l_node: GRAPHIFY_NODE
			l_id, l_kind, l_label: STRING
			j: INTEGER
		do
			from
				i := 1
			until
				i > a_nodes.count
			loop
				if attached a_nodes.object_item (i) as al_obj then
					l_id := string_field (al_obj, "id")
					l_kind := string_field (al_obj, "kind")
					l_label := string_field (al_obj, "label")
					if not l_id.is_empty and not l_kind.is_empty and not l_label.is_empty then
						create l_node.make (l_id, l_kind, l_label)
						l_node.set_location (string_field (al_obj, "file"), al_obj.integer_item ("line").to_integer_32.max (0))
						l_node.set_description (string_field (al_obj, "description"))
						l_node.set_community (al_obj.integer_item ("community").to_integer_32.max (0))
						l_node.set_degree (al_obj.integer_item ("degree").to_integer_32.max (0))
						if attached al_obj.array_item ("flags") as al_flags then
							from
								j := 1
							until
								j > al_flags.count
							loop
								if attached al_flags.string_item (j) as al_flag then
									l_node.add_flag (utf8 (al_flag))
								end
								j := j + 1
							end
						end
						if attached al_obj.object_item ("metrics") as al_metrics then
							across al_metrics.keys as ic_key loop
								l_node.set_metric (utf8 (ic_key), al_metrics.integer_item (ic_key).to_integer_32)
							end
						end
						a_graph.add_node (l_node)
					end
				end
				i := i + 1
			end
		end

	load_edges (a_graph: GRAPHIFY_GRAPH; a_edges: SIMPLE_JSON_ARRAY)
			-- Restore edges.
		local
			i: INTEGER
			l_edge: GRAPHIFY_EDGE
			l_from, l_to, l_kind, l_conf: STRING
		do
			from
				i := 1
			until
				i > a_edges.count
			loop
				if attached a_edges.object_item (i) as al_obj then
					l_from := string_field (al_obj, "from")
					l_to := string_field (al_obj, "to")
					l_kind := string_field (al_obj, "kind")
					l_conf := string_field (al_obj, "confidence")
					if not l_conf.same_string ("extracted") and not l_conf.same_string ("inferred") and not l_conf.same_string ("ambiguous") then
						l_conf := "ambiguous"
					end
					if not l_from.is_empty and not l_to.is_empty and not l_kind.is_empty and not l_from.same_string (l_to) then
						create l_edge.make (l_from, l_to, l_kind, l_conf)
						l_edge.set_weight (al_obj.integer_item ("weight").to_integer_32.max (1))
						l_edge.set_line (al_obj.integer_item ("line").to_integer_32.max (0))
						l_edge.set_why (string_field (al_obj, "why"))
						a_graph.add_edge (l_edge)
					end
				end
				i := i + 1
			end
		end

	load_communities (a_graph: GRAPHIFY_GRAPH; a_communities: SIMPLE_JSON_ARRAY)
			-- Restore communities (members from members_sample; full membership
			-- lives on the nodes' community field).
		local
			i, j: INTEGER
			l_community: GRAPHIFY_COMMUNITY
			l_id: INTEGER
			l_label: STRING
		do
			from
				i := 1
			until
				i > a_communities.count
			loop
				if attached a_communities.object_item (i) as al_obj then
					l_id := al_obj.integer_item ("id").to_integer_32
					l_label := string_field (al_obj, "label")
					if l_id >= 1 and not l_label.is_empty then
						create l_community.make (l_id, l_label)
						if attached al_obj.array_item ("members_sample") as al_members then
							from
								j := 1
							until
								j > al_members.count
							loop
								if attached al_members.string_item (j) as al_m then
									l_community.add_member (utf8 (al_m))
								end
								j := j + 1
							end
						end
						a_graph.add_community (l_community)
					end
				end
				i := i + 1
			end
		end

	load_god_nodes (a_graph: GRAPHIFY_GRAPH; a_gods: SIMPLE_JSON_ARRAY)
			-- Restore god-node ranking.
		local
			i: INTEGER
			l_ids: ARRAYED_LIST [STRING]
		do
			create l_ids.make (a_gods.count)
			from
				i := 1
			until
				i > a_gods.count
			loop
				if attached a_gods.string_item (i) as al_id then
					l_ids.extend (utf8 (al_id))
				end
				i := i + 1
			end
			a_graph.set_god_nodes (l_ids)
		end

	load_surprising (a_graph: GRAPHIFY_GRAPH; a_surprising: SIMPLE_JSON_ARRAY)
			-- Restore surprising connections (edges looked up by endpoints).
		local
			i: INTEGER
			l_from, l_to, l_reason: STRING
		do
			from
				i := 1
			until
				i > a_surprising.count
			loop
				if attached a_surprising.object_item (i) as al_obj then
					l_from := string_field (al_obj, "from")
					l_to := string_field (al_obj, "to")
					l_reason := string_field (al_obj, "reason")
					if not l_from.is_empty and not l_to.is_empty then
						if attached a_graph.edge_between (l_from, l_to) as al_edge then
							a_graph.add_surprising (al_edge, l_reason)
						end
					end
				end
				i := i + 1
			end
		end

	string_field (a_object: SIMPLE_JSON_OBJECT; a_key: STRING): STRING
			-- UTF-8 string at `a_key`; empty when absent.
		do
			if attached a_object.string_item (a_key.to_string_32) as al_value then
				Result := utf8 (al_value)
			else
				create Result.make_empty
			end
		ensure
			result_attached: Result /= Void
		end

end
