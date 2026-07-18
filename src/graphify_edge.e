note
	description: "A typed, confidence-tagged edge between two graph nodes"
	author: "Larry Rix"

class
	GRAPHIFY_EDGE

create
	make

feature {NONE} -- Initialization

	make (a_from, a_to, a_kind, a_confidence: STRING)
			-- Create edge `a_from` --`a_kind`--> `a_to` with `a_confidence`.
		require
			from_not_empty: not a_from.is_empty
			to_not_empty: not a_to.is_empty
			kind_not_empty: not a_kind.is_empty
			confidence_valid: a_confidence.same_string ("extracted")
				or a_confidence.same_string ("inferred")
				or a_confidence.same_string ("ambiguous")
			not_self_loop: not a_from.same_string (a_to)
		do
			from_id := a_from
			to_id := a_to
			kind := a_kind
			confidence := a_confidence
			weight := 1
			why := ""
		ensure
			from_set: from_id = a_from
			to_set: to_id = a_to
			kind_set: kind = a_kind
			confidence_set: confidence = a_confidence
			unit_weight: weight = 1
		end

feature -- Access

	from_id: STRING
			-- Source node id.

	to_id: STRING
			-- Target node id.

	kind: STRING
			-- One of: contains, depends_on, inherits, uses, creates, references, mentions.

	confidence: STRING
			-- One of: extracted, inferred, ambiguous.

	weight: INTEGER
			-- Occurrence count (merged duplicates accumulate here).

	line: INTEGER
			-- First occurrence line in the source node's file; 0 when unknown.

	why: STRING
			-- Short human explanation of the connection.

	key: STRING
			-- Dedup key over (from, to, kind).
		do
			create Result.make (from_id.count + to_id.count + kind.count + 2)
			Result.append (from_id)
			Result.append_character ('|')
			Result.append (to_id)
			Result.append_character ('|')
			Result.append (kind)
		ensure
			result_not_empty: not Result.is_empty
		end

feature -- Modification

	set_line (a_line: INTEGER)
			-- Set first-occurrence line.
		require
			line_non_negative: a_line >= 0
		do
			line := a_line
		ensure
			line_set: line = a_line
		end

	set_why (a_why: STRING)
			-- Set explanation.
		do
			why := a_why
		ensure
			why_set: why = a_why
		end

	set_weight (a_weight: INTEGER)
			-- Set occurrence count.
		require
			weight_positive: a_weight >= 1
		do
			weight := a_weight
		ensure
			weight_set: weight = a_weight
		end

	add_occurrence
			-- Record one more occurrence of this connection.
		do
			weight := weight + 1
		ensure
			weight_bumped: weight = old weight + 1
		end

	set_confidence (a_confidence: STRING)
			-- Set confidence tag.
		require
			confidence_valid: a_confidence.same_string ("extracted")
				or a_confidence.same_string ("inferred")
				or a_confidence.same_string ("ambiguous")
		do
			confidence := a_confidence
		ensure
			confidence_set: confidence = a_confidence
		end

	set_kind (a_kind: STRING)
			-- Reclassify edge kind (e.g. uses -> creates).
		require
			kind_not_empty: not a_kind.is_empty
		do
			kind := a_kind
		ensure
			kind_set: kind = a_kind
		end

invariant
	from_not_empty: not from_id.is_empty
	to_not_empty: not to_id.is_empty
	kind_not_empty: not kind.is_empty
	weight_positive: weight >= 1
	line_non_negative: line >= 0
	no_self_loop: not from_id.same_string (to_id)

end
