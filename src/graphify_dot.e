note
	description: "graph.dot exporter built on simple_graphviz DOT_GRAPH (render with any Graphviz tool)"
	author: "Larry Rix"

class
	GRAPHIFY_DOT

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make (a_graph: GRAPHIFY_GRAPH)
			-- Create exporter over `a_graph`.
		do
			graph := a_graph
		end

feature -- Access

	graph: GRAPHIFY_GRAPH
			-- Exported graph.

feature -- Basic operations

	dot_text: STRING
			-- Graphviz DOT representation of the knowledge graph.
		local
			l_dot: DOT_GRAPH
			l_node: DOT_NODE
			l_edge: DOT_EDGE
			l_color: STRING
		do
			create l_dot.make_digraph ("knowledge_graph")
			l_dot.set_rankdir ("LR").set_bgcolor ("white").do_nothing
			across graph.sorted_node_ids as ic_id loop
				if attached graph.node_by_id (ic_id) as al_n then
					l_node := l_dot.new_node (ic_id)
					l_color := Palette [(al_n.community \\ Palette.count) + 1]
					l_node.set_label (al_n.label).set_style ("filled").set_fillcolor (l_color).do_nothing
					if al_n.kind.same_string ("library") then
						l_node.set_shape ("box3d").do_nothing
					elseif al_n.kind.same_string ("cluster") then
						l_node.set_shape ("folder").do_nothing
					elseif al_n.kind.same_string ("document") then
						l_node.set_shape ("note").do_nothing
					elseif al_n.kind.same_string ("rationale") then
						l_node.set_shape ("diamond").do_nothing
					elseif al_n.kind.same_string ("feature") then
						l_node.set_shape ("ellipse").do_nothing
					else
						l_node.set_shape ("box").do_nothing
					end
				end
			end
			across graph.sorted_edges as ic_e loop
				l_edge := l_dot.new_edge (ic_e.from_id, ic_e.to_id)
				l_edge.set_label (ic_e.kind).do_nothing
				if ic_e.confidence.same_string ("inferred") then
					l_edge.set_style ("dashed").do_nothing
				elseif ic_e.confidence.same_string ("ambiguous") then
					l_edge.set_style ("dotted").do_nothing
				end
			end
			Result := l_dot.to_dot
		ensure
			result_not_empty: not Result.is_empty
		end

feature {NONE} -- Implementation

	Palette: ARRAY [STRING]
			-- Fill colors cycled by community id.
		once
			Result := <<"lightblue", "lightyellow", "lightpink", "lightgreen",
				"lavender", "peachpuff", "lightcyan", "mistyrose",
				"honeydew", "aliceblue", "cornsilk", "thistle">>
		end

invariant
	graph_attached: graph /= Void

end
