note
	description: "[
		Query engine: scores nodes against a natural-language question,
		expands the neighborhood, and renders compact markdown designed for
		AI-assistant consumption. Also provides explain, path, and stats views.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_QUERY

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create query engine over `a_graph`.
		do
			graph := a_graph
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Queried graph.

feature -- Queries

	answer (a_question: STRING; a_hops, a_limit: INTEGER): STRING
			-- Markdown subgraph answering `a_question`.
		require
			question_not_empty: not a_question.is_empty
			hops_non_negative: a_hops >= 0
			limit_positive: a_limit >= 1
		local
			l_tokens: ARRAYED_LIST [STRING]
			l_scored: ARRAYED_LIST [TUPLE [id: STRING; score: INTEGER]]
			l_selected, l_neighborhood: ARRAYED_LIST [STRING]
			l_in_set: HASH_TABLE [BOOLEAN, STRING]
			l_communities_hit: HASH_TABLE [BOOLEAN, INTEGER]
			l_edge_lines: ARRAYED_LIST [STRING]
		do
			l_tokens := question_tokens (a_question)
			l_scored := scored_nodes (l_tokens)
			create Result.make (4096)
			Result.append ("# Graph answer: %"" + a_question + "%"%N%N")
			if l_scored.is_empty then
				Result.append ("No graph nodes matched. Closest labels:%N")
				across closest_labels (a_question) as ic_l loop
					Result.append ("- " + ic_l + "%N")
				end
				Result.append ("%NTry `explain <NAME>` with one of these, or rebuild the graph.%N")
			else
				create l_selected.make (a_limit)
				across l_scored as ic_s loop
					if l_selected.count < a_limit then
						l_selected.extend (ic_s.id)
					end
				end
				create l_in_set.make (l_selected.count * 3)
				across l_selected as ic_id loop
					l_in_set.force (True, ic_id)
				end
				l_neighborhood := expanded_neighborhood (l_selected, a_hops, a_limit * 3, l_in_set)

				Result.append ("## Matched nodes (" + l_selected.count.out + ")%N%N")
				create l_communities_hit.make (8)
				across l_selected as ic_id loop
					if attached graph.node_by_id (ic_id) as al_node then
						Result.append (node_summary_line (al_node))
						if al_node.community > 0 then
							l_communities_hit.force (True, al_node.community)
						end
					end
				end

				create l_edge_lines.make (32)
				across l_neighborhood as ic_id loop
					across graph.edges_from (ic_id) as ic_e loop
						if l_in_set.has (ic_e.to_id) then
							l_edge_lines.extend ("- " + short_id (ic_e.from_id) + " --" + ic_e.kind
								+ "--> " + short_id (ic_e.to_id)
								+ " (" + ic_e.confidence + ", w" + ic_e.weight.out + ")")
						end
					end
				end
				l_edge_lines := merge_sorted (l_edge_lines)
				Result.append ("%N## Connections (" + l_edge_lines.count.out + ")%N%N")
				across l_edge_lines as ic_line loop
					Result.append (ic_line + "%N")
				end

				if not l_communities_hit.is_empty then
					Result.append ("%N## Communities involved%N%N")
					from
						l_communities_hit.start
					until
						l_communities_hit.after
					loop
						if attached graph.community_of (l_communities_hit.key_for_iteration) as al_c then
							Result.append ("- [" + al_c.id.out + "] " + al_c.label + " (" + al_c.size.out + " nodes)%N")
						end
						l_communities_hit.forth
					end
				end
				Result.append ("%N_Graph: " + graph.node_count.out + " nodes / " + graph.edge_count.out
					+ " edges. Drill down with `explain <NAME>` or `path <A> <B>`._%N")
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	explain (a_name: STRING): STRING
			-- Full markdown record of the node resolved from `a_name`.
		require
			name_not_empty: not a_name.is_empty
		local
			l_matches: ARRAYED_LIST [GRAPHIFY_NODE]
			l_rank: INTEGER
		do
			create Result.make (2048)
			l_matches := resolved_nodes (a_name)
			if l_matches.is_empty then
				Result.append ("Node not found: %"" + a_name + "%". Closest labels:%N")
				across closest_labels (a_name) as ic_l loop
					Result.append ("- " + ic_l + "%N")
				end
			elseif l_matches.count > 1 then
				Result.append ("Ambiguous name %"" + a_name + "%". Candidates:%N")
				across l_matches as ic_n loop
					Result.append ("- " + ic_n.id + "%N")
				end
			elseif attached l_matches.first as al_node then
				Result.append ("# " + al_node.label + " (" + al_node.kind + ")%N%N")
				if not al_node.description.is_empty then
					Result.append (al_node.description + "%N%N")
				end
				if not al_node.file_path.is_empty then
					Result.append ("- File: " + al_node.file_path + ":" + al_node.line.out + "%N")
				end
				Result.append ("- Degree: " + al_node.degree.out + "%N")
				if al_node.community > 0 then
					Result.append ("- Community: [" + al_node.community.out + "] "
						+ graph.community_label (al_node.community) + "%N")
				end
				if not al_node.flags.is_empty then
					Result.append ("- Flags: ")
					across al_node.flags as ic_f loop
						Result.append (ic_f + " ")
					end
					Result.append ("%N")
				end
				l_rank := god_rank (al_node.id)
				if l_rank > 0 then
					Result.append ("- God node rank: #" + l_rank.out + "%N")
				end
				if not al_node.metrics.is_empty then
					Result.append ("- Metrics: " + metrics_line (al_node) + "%N")
				end
				Result.append ("%N## Outgoing%N%N")
				append_edge_group (Result, graph.edges_from (al_node.id), True)
				Result.append ("%N## Incoming%N%N")
				append_edge_group (Result, graph.edges_to (al_node.id), False)
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	path_between (a_from, a_to: STRING): STRING
			-- Markdown shortest connection between resolved endpoints.
		require
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
		local
			l_from_nodes, l_to_nodes: ARRAYED_LIST [GRAPHIFY_NODE]
			l_path: ARRAYED_LIST [STRING]
			i: INTEGER
		do
			create Result.make (1024)
			l_from_nodes := resolved_nodes (a_from)
			l_to_nodes := resolved_nodes (a_to)
			if l_from_nodes.count /= 1 then
				Result.append (resolution_problem (a_from, l_from_nodes))
			elseif l_to_nodes.count /= 1 then
				Result.append (resolution_problem (a_to, l_to_nodes))
			elseif attached l_from_nodes.first as al_f and attached l_to_nodes.first as al_t then
				l_path := graph.shortest_path (al_f.id, al_t.id)
				if l_path.count < 2 then
					if al_f.id.same_string (al_t.id) then
						Result.append ("Both names resolve to the same node: " + al_f.id + "%N")
					else
						Result.append ("No path between " + al_f.id + " and " + al_t.id + ".%N")
					end
				else
					Result.append ("# Path: " + al_f.label + " -> " + al_t.label
						+ " (" + (l_path.count - 1).out + " hops)%N%N")
					from
						i := 1
					until
						i >= l_path.count
					loop
						if attached graph.edge_between (l_path [i], l_path [i + 1]) as al_edge then
							Result.append ((i).out + ". " + short_id (l_path [i]) + " --" + al_edge.kind
								+ "--> " + short_id (l_path [i + 1])
								+ " (" + al_edge.confidence + ")%N")
						else
							Result.append ((i).out + ". " + short_id (l_path [i]) + " -- " + short_id (l_path [i + 1]) + "%N")
						end
						i := i + 1
					end
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	stats_text: STRING
			-- Markdown statistics summary.
		local
			l_kind_counts: HASH_TABLE [INTEGER, STRING]
			l_keys: ARRAYED_LIST [STRING]
			l_shown: INTEGER
		do
			create Result.make (1024)
			Result.append ("# Graph stats%N%N")
			Result.append ("- Root: " + graph.root_path + "%N")
			Result.append ("- Generated: " + graph.generated_at + " (mode: " + graph.mode + ")%N")
			Result.append ("- Nodes: " + graph.node_count.out + " / Edges: " + graph.edge_count.out
				+ " / Communities: " + graph.communities.count.out + "%N")
			Result.append ("- Files scanned: " + graph.files_scanned.out
				+ " (classes: " + graph.classes_scanned.out
				+ ", documents: " + graph.documents_scanned.out + ")%N%N")

			create l_kind_counts.make (8)
			across graph.nodes as ic_n loop
				if l_kind_counts.has_key (ic_n.kind) then
					l_kind_counts.force (l_kind_counts.found_item + 1, ic_n.kind)
				else
					l_kind_counts.force (1, ic_n.kind)
				end
			end
			Result.append ("## Nodes by kind%N%N")
			create l_keys.make (l_kind_counts.count)
			from
				l_kind_counts.start
			until
				l_kind_counts.after
			loop
				l_keys.extend (l_kind_counts.key_for_iteration)
				l_kind_counts.forth
			end
			l_keys := merge_sorted (l_keys)
			across l_keys as ic_k loop
				if l_kind_counts.has_key (ic_k) then
					Result.append ("- " + ic_k + ": " + l_kind_counts.found_item.out + "%N")
				end
			end

			create l_kind_counts.make (8)
			across graph.edges as ic_e loop
				if l_kind_counts.has_key (ic_e.kind) then
					l_kind_counts.force (l_kind_counts.found_item + 1, ic_e.kind)
				else
					l_kind_counts.force (1, ic_e.kind)
				end
			end
			Result.append ("%N## Edges by kind%N%N")
			create l_keys.make (l_kind_counts.count)
			from
				l_kind_counts.start
			until
				l_kind_counts.after
			loop
				l_keys.extend (l_kind_counts.key_for_iteration)
				l_kind_counts.forth
			end
			l_keys := merge_sorted (l_keys)
			across l_keys as ic_k loop
				if l_kind_counts.has_key (ic_k) then
					Result.append ("- " + ic_k + ": " + l_kind_counts.found_item.out + "%N")
				end
			end

			Result.append ("%N## Top degrees%N%N")
			l_shown := 0
			across graph.god_node_ids as ic_id loop
				if l_shown < 10 and then attached graph.node_by_id (ic_id) as al_node then
					l_shown := l_shown + 1
					Result.append ("- " + al_node.label + " (" + al_node.kind + ", degree " + al_node.degree.out + ")%N")
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Name resolution

	resolved_nodes (a_name: STRING): ARRAYED_LIST [GRAPHIFY_NODE]
			-- Nodes matching `a_name`: exact id, else exact label, else
			-- case-insensitive label substring (all matches, capped at 8).
		require
			name_not_empty: not a_name.is_empty
		local
			l_lower: STRING
		do
			create Result.make (4)
			if attached graph.node_by_id (a_name) as al_exact then
				Result.extend (al_exact)
			else
				across graph.sorted_node_ids as ic_id loop
					if Result.is_empty and then attached graph.node_by_id (ic_id) as al_node then
						if al_node.label.is_case_insensitive_equal (a_name) then
							Result.extend (al_node)
						end
					end
				end
				if Result.is_empty then
					l_lower := a_name.as_lower
					across graph.sorted_node_ids as ic_id loop
						if Result.count < 8 and then attached graph.node_by_id (ic_id) as al_node then
							if al_node.label.as_lower.has_substring (l_lower) then
								Result.extend (al_node)
							end
						end
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Scoring

	question_tokens (a_question: STRING): ARRAYED_LIST [STRING]
			-- Lowercase alphanumeric tokens of `a_question` minus stopwords
			-- and short words.
		local
			i, l_start: INTEGER
			l_lower, l_word: STRING
		do
			create Result.make (8)
			l_lower := a_question.as_lower
			from
				i := 1
			until
				i > l_lower.count
			loop
				if l_lower [i].is_alpha_numeric or l_lower [i] = '_' then
					l_start := i
					from
					until
						i > l_lower.count or else not (l_lower [i].is_alpha_numeric or l_lower [i] = '_')
					loop
						i := i + 1
					end
					l_word := l_lower.substring (l_start, i - 1)
					if l_word.count >= 3 and not is_stopword (l_word) then
						Result.extend (l_word)
					end
				else
					i := i + 1
				end
			end
		ensure
			result_attached: Result /= Void
		end

	is_stopword (a_word: STRING): BOOLEAN
			-- Is `a_word` too common to score?
		do
			Result := a_word.same_string ("the") or a_word.same_string ("and")
				or a_word.same_string ("for") or a_word.same_string ("how")
				or a_word.same_string ("what") or a_word.same_string ("why")
				or a_word.same_string ("where") or a_word.same_string ("does")
				or a_word.same_string ("with") or a_word.same_string ("that")
				or a_word.same_string ("this") or a_word.same_string ("are")
				or a_word.same_string ("can") or a_word.same_string ("use")
				or a_word.same_string ("used") or a_word.same_string ("using")
				or a_word.same_string ("into") or a_word.same_string ("from")
				or a_word.same_string ("class") or a_word.same_string ("classes")
		end

	scored_nodes (a_tokens: ARRAYED_LIST [STRING]): ARRAYED_LIST [TUPLE [id: STRING; score: INTEGER]]
			-- Nodes with positive scores, best first (deterministic).
		local
			l_keys: ARRAYED_LIST [STRING]
			l_by_key: HASH_TABLE [TUPLE [id: STRING; score: INTEGER], STRING]
			l_score: INTEGER
			l_key: STRING
		do
			create l_keys.make (32)
			create l_by_key.make (32)
			across graph.sorted_node_ids as ic_id loop
				if attached graph.node_by_id (ic_id) as al_node then
					l_score := node_score (al_node, a_tokens)
					if l_score > 0 then
						l_key := padded_number (999999 - l_score, 6) + "|" + ic_id
						l_keys.extend (l_key)
						l_by_key.force ([ic_id, l_score], l_key)
					end
				end
			end
			l_keys := merge_sorted (l_keys)
			create Result.make (l_keys.count)
			across l_keys as ic_key loop
				if attached l_by_key.item (ic_key) as al_entry then
					Result.extend (al_entry)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	node_score (a_node: GRAPHIFY_NODE; a_tokens: ARRAYED_LIST [STRING]): INTEGER
			-- Relevance of `a_node` to `a_tokens`; class nodes score double.
		local
			l_label_lower, l_desc_lower, l_file_lower: STRING
			l_label_words: ARRAYED_LIST [STRING]
		do
			l_label_lower := a_node.label.as_lower
			l_desc_lower := a_node.description.as_lower
			l_file_lower := a_node.file_path.as_lower
			l_label_words := label_words (l_label_lower)
			across a_tokens as ic_tok loop
				if l_label_lower.same_string (ic_tok) then
					Result := Result + 100
				elseif l_label_lower.has_substring (ic_tok) then
					Result := Result + 60
				end
				across l_label_words as ic_w loop
					if ic_w.same_string (ic_tok) then
						Result := Result + 40
					end
				end
				if not l_desc_lower.is_empty and then l_desc_lower.has_substring (ic_tok) then
					Result := Result + 15
				end
				if not l_file_lower.is_empty and then l_file_lower.has_substring (ic_tok) then
					Result := Result + 10
				end
			end
			if Result > 0 and a_node.kind.same_string ("class") then
				Result := Result * 2
			end
		ensure
			non_negative: Result >= 0
		end

	label_words (a_label_lower: STRING): ARRAYED_LIST [STRING]
			-- Words of a label split on '_', '.', '/', '-'.
		local
			l_copy: STRING
			l_parts: LIST [STRING]
		do
			l_copy := a_label_lower.twin
			l_copy.replace_substring_all (".", "_")
			l_copy.replace_substring_all ("/", "_")
			l_copy.replace_substring_all ("-", "_")
			l_parts := l_copy.split ('_')
			create Result.make (l_parts.count)
			across l_parts as ic_p loop
				if not ic_p.is_empty then
					Result.extend (ic_p)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	expanded_neighborhood (a_seed: ARRAYED_LIST [STRING]; a_hops, a_cap: INTEGER; a_in_set: HASH_TABLE [BOOLEAN, STRING]): ARRAYED_LIST [STRING]
			-- `a_seed` plus up to `a_hops` hops of neighbors, total capped at
			-- `a_cap`; every included id is recorded in `a_in_set`.
		local
			l_frontier, l_next: ARRAYED_LIST [STRING]
			l_hop: INTEGER
		do
			create Result.make (a_cap)
			across a_seed as ic_id loop
				Result.extend (ic_id)
			end
			l_frontier := a_seed
			from
				l_hop := 1
			until
				l_hop > a_hops or Result.count >= a_cap
			loop
				create l_next.make (16)
				across l_frontier as ic_id loop
					across merge_sorted (graph.undirected_neighbors (ic_id, False)) as ic_n loop
						if Result.count < a_cap and then not a_in_set.has (ic_n) then
							a_in_set.force (True, ic_n)
							Result.extend (ic_n)
							l_next.extend (ic_n)
						end
					end
				end
				l_frontier := l_next
				l_hop := l_hop + 1
			end
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Rendering helpers

	node_summary_line (a_node: GRAPHIFY_NODE): STRING
			-- One compact markdown bullet for `a_node`.
		do
			create Result.make (160)
			Result.append ("- **" + a_node.label + "** (" + a_node.kind)
			if not a_node.file_path.is_empty then
				Result.append (", " + a_node.file_path + ":" + a_node.line.out)
			end
			Result.append (", degree " + a_node.degree.out + ")")
			if not a_node.description.is_empty then
				Result.append (" - " + a_node.description)
			end
			Result.append ("%N")
		end

	metrics_line (a_node: GRAPHIFY_NODE): STRING
			-- Sorted "k=v" listing of node metrics.
		local
			l_keys: ARRAYED_LIST [STRING]
			l_first: BOOLEAN
		do
			create Result.make (80)
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
				Result.append (ic_k + "=" + a_node.metric (ic_k).out)
			end
		end

	append_edge_group (a_target: STRING; a_edges: ARRAYED_LIST [GRAPHIFY_EDGE]; a_outgoing: BOOLEAN)
			-- Append sorted edge bullets to `a_target`.
		local
			l_lines: ARRAYED_LIST [STRING]
		do
			create l_lines.make (a_edges.count)
			across a_edges as ic_e loop
				if a_outgoing then
					l_lines.extend ("- --" + ic_e.kind + "--> " + short_id (ic_e.to_id)
						+ " (" + ic_e.confidence + ", w" + ic_e.weight.out
						+ edge_why_suffix (ic_e) + ")")
				else
					l_lines.extend ("- " + short_id (ic_e.from_id) + " --" + ic_e.kind
						+ "--> (this) (" + ic_e.confidence + ", w" + ic_e.weight.out
						+ edge_why_suffix (ic_e) + ")")
				end
			end
			l_lines := merge_sorted (l_lines)
			if l_lines.is_empty then
				a_target.append ("(none)%N")
			else
				across l_lines as ic_line loop
					a_target.append (ic_line + "%N")
				end
			end
		end

	edge_why_suffix (a_edge: GRAPHIFY_EDGE): STRING
			-- ", why" suffix when a why is recorded.
		do
			if a_edge.why.is_empty then
				create Result.make_empty
			else
				Result := ", " + a_edge.why
			end
		end

	short_id (a_id: STRING): STRING
			-- `a_id` without its kind prefix.
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

	god_rank (a_id: STRING): INTEGER
			-- 1-based god-node rank of `a_id`; 0 when unranked.
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > graph.god_node_ids.count or Result > 0
			loop
				if graph.god_node_ids [i].same_string (a_id) then
					Result := i
				end
				i := i + 1
			end
		end

	resolution_problem (a_name: STRING; a_matches: ARRAYED_LIST [GRAPHIFY_NODE]): STRING
			-- Explanation of a failed or ambiguous resolution.
		do
			create Result.make (256)
			if a_matches.is_empty then
				Result.append ("Node not found: %"" + a_name + "%". Closest labels:%N")
				across closest_labels (a_name) as ic_l loop
					Result.append ("- " + ic_l + "%N")
				end
			else
				Result.append ("Ambiguous name %"" + a_name + "%". Candidates:%N")
				across a_matches as ic_n loop
					Result.append ("- " + ic_n.id + "%N")
				end
			end
		end

	closest_labels (a_name: STRING): ARRAYED_LIST [STRING]
			-- Up to 5 labels sharing a leading fragment or token with `a_name`.
		local
			l_lower, l_frag: STRING
		do
			create Result.make (5)
			l_lower := a_name.as_lower
			l_frag := l_lower
			if l_frag.count > 4 then
				l_frag := l_frag.substring (1, 4)
			end
			across graph.sorted_node_ids as ic_id loop
				if Result.count < 5 and then attached graph.node_by_id (ic_id) as al_node then
					if al_node.label.as_lower.has_substring (l_frag) then
						Result.extend (al_node.label)
					end
				end
			end
		ensure
			result_attached: Result /= Void
		end

invariant
	graph_attached: graph /= Void

end
