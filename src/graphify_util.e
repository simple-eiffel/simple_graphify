note
	description: "[
		Shared string, path, and sorting helpers for simple_graphify.
		Intended as a mixin: scanners and emitters inherit these features.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_UTIL

feature -- String conversion

	utf8 (a_text: READABLE_STRING_GENERAL): STRING
			-- UTF-8 byte encoding of `a_text`.
		local
			l_conv: UTF_CONVERTER
		do
			Result := l_conv.utf_32_string_to_utf_8_string_8 (a_text)
		ensure
			result_attached: Result /= Void
		end

	utf8_to_string_32 (a_bytes: READABLE_STRING_8): STRING_32
			-- Decode UTF-8 bytes `a_bytes` to a Unicode string.
		local
			l_conv: UTF_CONVERTER
		do
			Result := l_conv.utf_8_string_8_to_string_32 (a_bytes)
		ensure
			result_attached: Result /= Void
		end

feature -- Path helpers

	normalized_path (a_path: READABLE_STRING_GENERAL): STRING
			-- `a_path` as UTF-8 with '/' separators.
		do
			Result := utf8 (a_path)
			Result.replace_substring_all ("\", "/")
		ensure
			no_backslashes: not Result.has ('\')
		end

	relative_to (a_root, a_path: STRING): STRING
			-- `a_path` made relative to `a_root` when it lies underneath (case-insensitive).
		require
			root_not_empty: not a_root.is_empty
		local
			l_root: STRING
		do
			l_root := a_root.twin
			if not l_root.ends_with ("/") then
				l_root.append_character ('/')
			end
			if a_path.count > l_root.count and then a_path.as_lower.starts_with (l_root.as_lower) then
				Result := a_path.substring (l_root.count + 1, a_path.count)
			else
				Result := a_path
			end
		ensure
			result_attached: Result /= Void
		end

	path_base_stem (a_path: STRING): STRING
			-- File name of `a_path` without directory or extension.
		local
			l_slash, l_dot: INTEGER
		do
			l_slash := a_path.last_index_of ('/', a_path.count)
			Result := a_path.substring (l_slash + 1, a_path.count)
			l_dot := Result.last_index_of ('.', Result.count)
			if l_dot > 1 then
				Result := Result.substring (1, l_dot - 1)
			end
		ensure
			result_attached: Result /= Void
		end

feature -- Text helpers

	first_line_of (a_text: STRING; a_max: INTEGER): STRING
			-- First non-empty line of `a_text`, trimmed and truncated to `a_max` characters.
		require
			max_positive: a_max >= 1
		local
			l_lines: LIST [STRING]
			l_line: STRING
		do
			create Result.make_empty
			l_lines := a_text.split ('%N')
			from
				l_lines.start
			until
				l_lines.after or not Result.is_empty
			loop
				l_line := l_lines.item.twin
				l_line.prune_all ('%R')
				l_line.left_adjust
				l_line.right_adjust
				if not l_line.is_empty then
					Result := l_line
				end
				l_lines.forth
			end
			if Result.count > a_max then
				Result := Result.substring (1, a_max)
			end
		ensure
			bounded: Result.count <= a_max
		end

	json_escaped (a_text: STRING): STRING
			-- `a_text` with JSON string escaping applied.
		local
			i: INTEGER
			c: CHARACTER
		do
			create Result.make (a_text.count + 8)
			from
				i := 1
			until
				i > a_text.count
			loop
				c := a_text [i]
				if c = '"' then
					Result.append ("\%"")
				elseif c = '\' then
					Result.append ("\\")
				elseif c = '%N' then
					Result.append ("\n")
				elseif c = '%R' then
					Result.append ("\r")
				elseif c = '%T' then
					Result.append ("\t")
				elseif c.code < 32 then
					Result.append ("\u")
					Result.append (padded_hex (c.code))
				else
					Result.append_character (c)
				end
				i := i + 1
			end
		ensure
			result_attached: Result /= Void
		end

	padded_hex (a_code: INTEGER): STRING
			-- 4-digit lowercase hex of `a_code`.
		require
			code_in_range: a_code >= 0 and a_code < 65536
		local
			l_digits: STRING
			l_value, l_pos: INTEGER
		do
			l_digits := "0123456789abcdef"
			create Result.make_filled ('0', 4)
			from
				l_value := a_code
				l_pos := 4
			until
				l_value = 0 or l_pos < 1
			loop
				Result [l_pos] := l_digits [(l_value \\ 16) + 1]
				l_value := l_value // 16
				l_pos := l_pos - 1
			end
		ensure
			four_digits: Result.count = 4
		end

	padded_number (a_value, a_width: INTEGER): STRING
			-- `a_value` as decimal string left-padded with zeros to `a_width`.
		require
			value_non_negative: a_value >= 0
			width_positive: a_width >= 1
		do
			Result := a_value.out
			from
			until
				Result.count >= a_width
			loop
				Result.prepend ("0")
			end
		ensure
			wide_enough: Result.count >= a_width
		end

feature -- Sorting

	sort_strings (a_list: ARRAYED_LIST [STRING])
			-- Sort `a_list` ascending (stable merge sort).
		local
			l_sorted: ARRAYED_LIST [STRING]
		do
			l_sorted := merge_sorted (a_list)
			a_list.wipe_out
			across l_sorted as ic_s loop
				a_list.extend (ic_s)
			end
		ensure
			same_count: a_list.count = old a_list.count
		end

	merge_sorted (a_list: ARRAYED_LIST [STRING]): ARRAYED_LIST [STRING]
			-- Ascending copy of `a_list` (merge sort).
		local
			l_left, l_right: ARRAYED_LIST [STRING]
			l_mid, i: INTEGER
		do
			if a_list.count <= 1 then
				create Result.make (a_list.count)
				across a_list as ic_s loop
					Result.extend (ic_s)
				end
			else
				l_mid := a_list.count // 2
				create l_left.make (l_mid)
				create l_right.make (a_list.count - l_mid)
				from
					i := 1
				until
					i > a_list.count
				loop
					if i <= l_mid then
						l_left.extend (a_list [i])
					else
						l_right.extend (a_list [i])
					end
					i := i + 1
				end
				Result := merged (merge_sorted (l_left), merge_sorted (l_right))
			end
		ensure
			same_count: Result.count = a_list.count
		end

feature -- Identifier scanning

	is_ident_char (a_char: CHARACTER): BOOLEAN
			-- Is `a_char` part of an ALL_CAPS identifier?
		do
			Result := (a_char >= 'A' and a_char <= 'Z')
				or (a_char >= '0' and a_char <= '9')
				or a_char = '_'
		end

	upper_tokens (a_text: STRING): ARRAYED_LIST [TUPLE [token: STRING; position: INTEGER]]
			-- ALL_CAPS identifier tokens (length >= 3, starting with a letter) in `a_text`
			-- with their 1-based start positions. Tokens adjoining lowercase letters are skipped.
		local
			i, l_start: INTEGER
			l_token: STRING
			l_boundary_ok: BOOLEAN
		do
			create Result.make (16)
			from
				i := 1
			until
				i > a_text.count
			loop
				if a_text [i] >= 'A' and a_text [i] <= 'Z' then
					l_start := i
					from
					until
						i > a_text.count or else not is_ident_char (a_text [i])
					loop
						i := i + 1
					end
					l_token := a_text.substring (l_start, i - 1)
					l_boundary_ok := True
					if l_start > 1 and then (a_text [l_start - 1].is_alpha or a_text [l_start - 1] = '_' or a_text [l_start - 1].is_digit) then
						l_boundary_ok := False
					end
					if i <= a_text.count and then a_text [i].is_alpha then
						l_boundary_ok := False
					end
					if l_boundary_ok and l_token.count >= 3 then
						Result.extend ([l_token, l_start])
					end
				else
					i := i + 1
				end
			end
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Implementation

	merged (a_left, a_right: ARRAYED_LIST [STRING]): ARRAYED_LIST [STRING]
			-- Ascending merge of two ascending lists.
		local
			i, j: INTEGER
		do
			create Result.make (a_left.count + a_right.count)
			from
				i := 1
				j := 1
			until
				i > a_left.count and j > a_right.count
			loop
				if j > a_right.count or else (i <= a_left.count and then a_left [i] <= a_right [j]) then
					Result.extend (a_left [i])
					i := i + 1
				else
					Result.extend (a_right [j])
					j := j + 1
				end
			end
		ensure
			total_count: Result.count = a_left.count + a_right.count
		end

end
