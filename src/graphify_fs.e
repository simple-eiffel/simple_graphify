note
	description: "[
		Recursive directory walker collecting ECF, Eiffel source, and markdown
		files under a root. Skips generated, hidden, and deprecated folders.
	]"
	author: "Larry Rix"

class
	GRAPHIFY_FS

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Create walker with empty results.
		do
			create ecf_files.make (10)
			create eiffel_files.make (100)
			create doc_files.make (20)
			create excluded_names.make (4)
		end

feature -- Access

	ecf_files: ARRAYED_LIST [STRING]
			-- Absolute paths ('/' separators) of *.ecf files found.

	eiffel_files: ARRAYED_LIST [STRING]
			-- Absolute paths of *.e files found.

	doc_files: ARRAYED_LIST [STRING]
			-- Absolute paths of *.md files found.

	total_count: INTEGER
			-- All collected files.
		do
			Result := ecf_files.count + eiffel_files.count + doc_files.count
		end

	excluded_names: ARRAYED_LIST [STRING]
			-- Additional directory names pruned from the walk (lowercase).

feature -- Configuration

	set_excluded (a_names: ARRAYED_LIST [STRING])
			-- Prune directories named as in `a_names` (case-insensitive).
		do
			excluded_names.wipe_out
			across a_names as ic_n loop
				if not ic_n.is_empty then
					excluded_names.extend (ic_n.as_lower)
				end
			end
		end

feature -- Basic operations

	collect (a_root: STRING)
			-- Walk `a_root` recursively, filling the file lists (sorted).
		require
			root_not_empty: not a_root.is_empty
		do
			ecf_files.wipe_out
			eiffel_files.wipe_out
			doc_files.wipe_out
			walk (normalized_path (a_root))
			sort_strings (ecf_files)
			sort_strings (eiffel_files)
			sort_strings (doc_files)
		end

	is_skipped_directory (a_name: STRING): BOOLEAN
			-- Should directory `a_name` be pruned from the walk?
		local
			l_lower: STRING
		do
			l_lower := a_name.as_lower
			Result := a_name.starts_with (".")
				or l_lower.same_string ("eifgens")
				or l_lower.same_string ("eifdata")
				or l_lower.same_string ("_deprecated")
				or l_lower.same_string ("node_modules")
				or l_lower.same_string ("graphify-out")
				or l_lower.same_string ("bin")
			across excluded_names as ic_x loop
				if l_lower.same_string (ic_x) then
					Result := True
				end
			end
		end

feature {NONE} -- Implementation

	walk (a_dir: STRING)
			-- Recurse into `a_dir` collecting files.
		local
			l_dir: SIMPLE_FILE
			l_names: ARRAYED_LIST [STRING]
			l_full, l_lower: STRING
		do
			create l_dir.make (a_dir)
			create l_names.make (20)
			across l_dir.files as ic_f loop
				l_names.extend (utf8 (ic_f))
			end
			across l_names as ic_name loop
				l_full := a_dir + "/" + ic_name
				l_lower := ic_name.as_lower
				if l_lower.ends_with (".ecf") then
					ecf_files.extend (l_full)
				elseif l_lower.ends_with (".e") then
					eiffel_files.extend (l_full)
				elseif l_lower.ends_with (".md") then
					doc_files.extend (l_full)
				end
			end
			create l_names.make (10)
			across l_dir.directories as ic_d loop
				l_names.extend (utf8 (ic_d))
			end
			across l_names as ic_name loop
				if not is_skipped_directory (ic_name) then
					walk (a_dir + "/" + ic_name)
				end
			end
		end

end
