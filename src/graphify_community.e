note
	description: "A detected community: a cluster of related graph nodes with a human label"
	author: "Larry Rix"

class
	GRAPHIFY_COMMUNITY

create
	make

feature {NONE} -- Initialization

	make (a_id: INTEGER; a_label: STRING)
			-- Create community `a_id` labeled `a_label`.
		require
			id_positive: a_id >= 1
			label_not_empty: not a_label.is_empty
		do
			id := a_id
			label := a_label
			create members.make (10)
		ensure
			id_set: id = a_id
			label_set: label = a_label
		end

feature -- Access

	id: INTEGER
			-- Community number (1-based, ordered by descending size).

	label: STRING
			-- Human label, e.g. "simple_http core".

	members: ARRAYED_LIST [STRING]
			-- Member node ids (sorted).

	size: INTEGER
			-- Member count.
		do
			Result := members.count
		ensure
			definition: Result = members.count
		end

feature -- Modification

	add_member (a_node_id: STRING)
			-- Add member node id.
		require
			id_not_empty: not a_node_id.is_empty
		do
			members.extend (a_node_id)
		ensure
			one_more: members.count = old members.count + 1
		end

	set_label (a_label: STRING)
			-- Set human label.
		require
			label_not_empty: not a_label.is_empty
		do
			label := a_label
		ensure
			label_set: label = a_label
		end

invariant
	id_positive: id >= 1
	label_not_empty: not label.is_empty

end
