note
	description: "A node in the knowledge graph: library, cluster, class, feature, document, or rationale tag"
	author: "Larry Rix"

class
	GRAPHIFY_NODE

create
	make

feature {NONE} -- Initialization

	make (a_id, a_kind, a_label: STRING)
			-- Create node with identity `a_id`, kind `a_kind`, display label `a_label`.
		require
			id_not_empty: not a_id.is_empty
			kind_not_empty: not a_kind.is_empty
			label_not_empty: not a_label.is_empty
		do
			id := a_id
			kind := a_kind
			label := a_label
			file_path := ""
			description := ""
			create flags.make (2)
			create metrics.make (8)
		ensure
			id_set: id = a_id
			kind_set: kind = a_kind
			label_set: label = a_label
		end

feature -- Access

	id: STRING
			-- Unique identity, e.g. "class:SIMPLE_HTTP".

	kind: STRING
			-- One of: library, cluster, class, feature, document, rationale.

	label: STRING
			-- Display name.

	file_path: STRING
			-- Root-relative source path with '/' separators; empty when not applicable.

	line: INTEGER
			-- Declaration line in `file_path`; 0 when not applicable.

	description: STRING
			-- Short human description (<= 200 chars).

	flags: ARRAYED_LIST [STRING]
			-- Qualities such as "deferred", "expanded", "frozen", "external".

	metrics: HASH_TABLE [INTEGER, STRING]
			-- Named counts, e.g. "features", "preconditions", "loc".

	community: INTEGER
			-- Community id assigned by analysis; 0 = unassigned.

	degree: INTEGER
			-- Undirected degree computed by analysis.

feature -- Status report

	has_flag (a_flag: STRING): BOOLEAN
			-- Does node carry `a_flag`?
		require
			flag_not_empty: not a_flag.is_empty
		do
			across flags as ic_f loop
				if ic_f.same_string (a_flag) then
					Result := True
				end
			end
		end

feature -- Modification

	set_location (a_file: STRING; a_line: INTEGER)
			-- Set source location.
		require
			line_non_negative: a_line >= 0
		do
			file_path := a_file
			line := a_line
		ensure
			file_set: file_path = a_file
			line_set: line = a_line
		end

	set_description (a_text: STRING)
			-- Set `description`.
		do
			description := a_text
		ensure
			description_set: description = a_text
		end

	add_flag (a_flag: STRING)
			-- Add `a_flag` when absent.
		require
			flag_not_empty: not a_flag.is_empty
		do
			if not has_flag (a_flag) then
				flags.extend (a_flag)
			end
		ensure
			flag_present: has_flag (a_flag)
		end

	set_metric (a_name: STRING; a_value: INTEGER)
			-- Record metric `a_name` = `a_value`.
		require
			name_not_empty: not a_name.is_empty
		do
			metrics.force (a_value, a_name)
		ensure
			metric_set: metrics.has (a_name)
		end

	metric (a_name: STRING): INTEGER
			-- Value of metric `a_name`; 0 when absent.
		require
			name_not_empty: not a_name.is_empty
		do
			if metrics.has_key (a_name) then
				Result := metrics.found_item
			end
		end

	set_community (a_community: INTEGER)
			-- Assign community id.
		require
			community_non_negative: a_community >= 0
		do
			community := a_community
		ensure
			community_set: community = a_community
		end

	set_degree (a_degree: INTEGER)
			-- Set computed degree.
		require
			degree_non_negative: a_degree >= 0
		do
			degree := a_degree
		ensure
			degree_set: degree = a_degree
		end

invariant
	id_not_empty: not id.is_empty
	kind_not_empty: not kind.is_empty
	label_not_empty: not label.is_empty
	line_non_negative: line >= 0
	community_non_negative: community >= 0
	degree_non_negative: degree >= 0

end
