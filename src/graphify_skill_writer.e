note
	description: "Writes the Claude Code skill that teaches graph-first querying with simple_graphify"
	author: "Larry Rix"

class
	GRAPHIFY_SKILL_WRITER

inherit
	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Create writer.
		do
			last_error := ""
		end

feature -- Access

	last_error: STRING
			-- Problem from last `install`; empty when none.

	skill_relative_path: STRING = ".claude/skills/graphify-eiffel/SKILL.md"
			-- Where the skill lands inside a project.

feature -- Basic operations

	install (a_project_dir, a_exe_path: STRING): BOOLEAN
			-- Write the skill into `a_project_dir`, wiring the absolute
			-- `a_exe_path` of simple_graphify.exe. True on success.
		require
			project_not_empty: not a_project_dir.is_empty
			exe_not_empty: not a_exe_path.is_empty
		local
			l_dir: SIMPLE_FILE
			l_file: SIMPLE_FILE
			l_skill_dir, l_content: STRING
		do
			last_error := ""
			l_skill_dir := normalized_path (a_project_dir) + "/.claude/skills/graphify-eiffel"
			create l_dir.make (l_skill_dir)
			if l_dir.create_directory_recursive or l_dir.is_directory then
				l_content := skill_text (a_exe_path)
				create l_file.make (l_skill_dir + "/SKILL.md")
				Result := l_file.set_content (utf8_to_string_32 (l_content))
				if not Result then
					last_error := "Cannot write " + l_skill_dir + "/SKILL.md"
				end
			else
				last_error := "Cannot create " + l_skill_dir
			end
		ensure
			error_on_failure: not Result implies not last_error.is_empty
		end

	skill_text (a_exe_path: STRING): STRING
			-- SKILL.md content with `a_exe_path` substituted and the
			-- template's source indentation stripped (YAML frontmatter
			-- must start at column 0).
		require
			exe_not_empty: not a_exe_path.is_empty
		local
			l_lines: LIST [STRING]
			l_line: STRING
		do
			create Result.make (Skill_template.count)
			l_lines := Skill_template.split ('%N')
			across l_lines as ic_line loop
				l_line := ic_line.twin
				if l_line.count >= 2 and then (l_line [1] = '%T' and l_line [2] = '%T') then
					l_line.remove_head (2)
				elseif l_line.count >= 1 and then l_line [1] = '%T' then
					l_line.remove_head (1)
				end
				Result.append (l_line)
				Result.append_character ('%N')
			end
			Result.replace_substring_all ("__EXE__", normalized_path (a_exe_path))
		ensure
			result_not_empty: not Result.is_empty
			substituted: not Result.has_substring ("__EXE__")
		end

feature {NONE} -- Template

	Skill_template: STRING = "[
		---
		name: graphify-eiffel
		description: Query the pre-built knowledge graph of this Eiffel project instead of grepping files. Use for structural questions - "how is X wired", "what depends on Y", "how do A and B connect", "explain CLASS", architecture/subsystem overviews, impact analysis. Also use to (re)build the graph after large structural changes with the build command.
		---

		# graphify-eiffel: knowledge-graph-first codebase questions

		This project has (or can build) a knowledge graph produced by simple_graphify:
		nodes are libraries, clusters, classes, features, documents, and design-rationale
		tags; edges are typed (inherits, uses, creates, contains, depends_on, references,
		mentions) and confidence-tagged (extracted = explicit in source, inferred =
		derived, ambiguous = uncertain).

		The graph is the token-efficient way to answer structural questions.
		ALWAYS prefer a graph query over Glob/Grep exploration when the question is
		about structure, wiring, dependencies, or architecture.

		## Commands (run via Bash)

		Build or refresh the graph (run once per repo, or after big refactors):

		    __EXE__ build <project-root>

		Outputs land in <project-root>/graphify-out/: graph.json, GRAPH_REPORT.md,
		graph.html (interactive), graph.dot (Graphviz).

		Query (run from the project root, or pass --graph <path-to-graph.json>):

		    __EXE__ query "how does the response cache work"
		    __EXE__ explain SIMPLE_HTTP
		    __EXE__ path SIMPLE_HTTP HTTP_COOKIE_JAR
		    __EXE__ stats

		- `query` returns matched nodes + connections + communities as compact markdown.
		  Use `--hops 2` for wider context and `--limit N` to cap matches.
		- `explain` returns one node with ALL its edges - best for "tell me about CLASS".
		- `path` returns the shortest connection chain - best for "how do A and B relate".

		## Reading results

		- God nodes (see GRAPH_REPORT.md) are the integration hubs - start there.
		- Edge confidence: trust `extracted` fully; verify `inferred`/`ambiguous`
		  against source before making claims.
		- Every node carries file:line - jump straight to the source when detail
		  is needed instead of re-searching.

		## Semantic enrichment (you are the LLM pass)

		When you infer a non-obvious connection from reading docs or code (e.g. a
		design doc explains WHY two subsystems are linked), record it:

		1. Write edges.json: {"edges":[{"from":"class:A","to":"doc:docs/design.md",
		   "kind":"references","why":"design rationale"}]}
		2. Run: __EXE__ annotate edges.json

		Merged edges are tagged `inferred`. Endpoints must be existing node ids.

		## When NOT to use the graph

		- Reading or editing specific code you already located: open the file.
		- Questions about runtime behavior/values: graphs are structural only.
		- If graph.json is missing and the user only asked a trivial question,
		  do not force a build; but for repeated structural work, build once.
	]"

end
