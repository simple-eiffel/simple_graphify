note
	description: "simple_graphify CLI: build/query/explain/path/stats/report/annotate/install"
	author: "Larry Rix"

class
	GRAPHIFY_APP

inherit
	EXCEPTIONS

	GRAPHIFY_UTIL

create
	make

feature {NONE} -- Initialization

	make
			-- Parse arguments and dispatch.
		local
			l_cli: SIMPLE_CLI
			l_command: STRING
		do
			create facade.make
			create l_cli.make
			l_cli.set_app_info ("simple_graphify",
				"Knowledge graph extractor and query tool for Eiffel projects", Version)
			l_cli.option_def ("out", "Output directory for build artifacts", "DIR")
			l_cli.option_def ("graph", "Path to graph.json for query commands", "FILE")
			l_cli.option_def ("mode", "Build mode: standard or deep", "MODE")
			l_cli.option_def ("hops", "Neighborhood expansion hops for query", "N")
			l_cli.option_def ("limit", "Maximum matched nodes for query", "N")
			l_cli.option_def ("project", "Project directory for install", "DIR")
			l_cli.option_def ("exclude", "Comma-separated directory names to skip during build", "NAMES")
			l_cli.flag ("no-docs", "Skip markdown document scanning")
			l_cli.flag ("full-deps", "Include external ISE/Gobo dependencies as nodes")
			l_cli.flag ("quiet", "Suppress progress output")
			l_cli.parse
			cli := l_cli

			if l_cli.help_requested then
				io.put_string (l_cli.help_message)
				print_commands
			elseif l_cli.version_requested then
				io.put_string ("simple_graphify " + Version + "%N")
			elseif attached l_cli.first_arg as al_command then
				l_command := al_command
				dispatch (l_command)
			else
				io.put_string ("Usage: simple_graphify <command> [args] [options]%N")
				print_commands
				die (Exit_usage)
			end
		end

feature {NONE} -- Dispatch

	facade: SIMPLE_GRAPHIFY
			-- Library facade.

	cli: detachable SIMPLE_CLI
			-- Parsed command line.

	dispatch (a_command: STRING)
			-- Execute `a_command`.
		do
			if a_command.same_string ("build") then
				run_build
			elseif a_command.same_string ("query") then
				run_query
			elseif a_command.same_string ("explain") then
				run_explain
			elseif a_command.same_string ("path") then
				run_path
			elseif a_command.same_string ("stats") then
				run_stats
			elseif a_command.same_string ("report") then
				run_report
			elseif a_command.same_string ("annotate") then
				run_annotate
			elseif a_command.same_string ("install") then
				run_install
			elseif a_command.same_string ("version") then
				io.put_string ("simple_graphify " + Version + "%N")
			else
				io.put_string ("Unknown command: " + a_command + "%N")
				print_commands
				die (Exit_usage)
			end
		end

	run_build
			-- build <path> [--out DIR] [--mode standard|deep] [--no-docs] [--full-deps]
		local
			l_root, l_out: STRING
			l_deep: BOOLEAN
		do
			if attached cli as al_cli then
				l_root := sub_argument (1, ".")
				l_out := option_or (al_cli, "out", "")
				l_deep := option_or (al_cli, "mode", "standard").same_string ("deep")
				facade.set_exclusions (option_or (al_cli, "exclude", ""))
				if not al_cli.flag_exists ("quiet") then
					io.put_string ("Building knowledge graph from " + l_root + " ...%N")
				end
				if facade.build (l_root, l_out, l_deep, not al_cli.flag_exists ("no-docs"), al_cli.flag_exists ("full-deps")) then
					io.put_string (facade.last_summary)
				else
					io.put_string ("BUILD FAILED: " + facade.last_error + "%N")
					die (Exit_no_content)
				end
			end
		end

	run_query
			-- query "<question>" [--graph FILE] [--hops N] [--limit N]
		local
			l_question: STRING
			l_hops, l_limit: INTEGER
		do
			if attached cli as al_cli then
				l_question := sub_argument (1, "")
				if l_question.is_empty then
					io.put_string ("Usage: simple_graphify query %"<question>%" [--graph FILE] [--hops N] [--limit N]%N")
					die (Exit_usage)
				elseif load_graph (al_cli) then
					l_hops := option_integer (al_cli, "hops", 1)
					l_limit := option_integer (al_cli, "limit", 30)
					io.put_string (facade.query (l_question, l_hops.max (0), l_limit.max (1)))
				end
			end
		end

	run_explain
			-- explain <NAME> [--graph FILE]
		local
			l_name: STRING
		do
			if attached cli as al_cli then
				l_name := sub_argument (1, "")
				if l_name.is_empty then
					io.put_string ("Usage: simple_graphify explain <NODE-OR-NAME> [--graph FILE]%N")
					die (Exit_usage)
				elseif load_graph (al_cli) then
					io.put_string (facade.explain (l_name))
				end
			end
		end

	run_path
			-- path <A> <B> [--graph FILE]
		local
			l_from, l_to: STRING
		do
			if attached cli as al_cli then
				l_from := sub_argument (1, "")
				l_to := sub_argument (2, "")
				if l_from.is_empty or l_to.is_empty then
					io.put_string ("Usage: simple_graphify path <A> <B> [--graph FILE]%N")
					die (Exit_usage)
				elseif load_graph (al_cli) then
					io.put_string (facade.path_between (l_from, l_to))
				end
			end
		end

	run_stats
			-- stats [--graph FILE]
		do
			if attached cli as al_cli and then load_graph (al_cli) then
				io.put_string (facade.stats)
			end
		end

	run_report
			-- report [--graph FILE]
		do
			if attached cli as al_cli and then load_graph (al_cli) then
				io.put_string (facade.report)
			end
		end

	run_annotate
			-- annotate <edges.json> [--graph FILE]
		local
			l_edges, l_graph_path: STRING
		do
			if attached cli as al_cli then
				l_edges := sub_argument (1, "")
				if l_edges.is_empty then
					io.put_string ("Usage: simple_graphify annotate <edges.json> [--graph FILE]%N")
					die (Exit_usage)
				else
					l_graph_path := graph_path_of (al_cli)
					io.put_string (facade.annotate (l_edges, l_graph_path))
					if not facade.last_error.is_empty then
						die (Exit_annotate_failed)
					end
				end
			end
		end

	run_install
			-- install [--project DIR]
		local
			l_project: STRING
		do
			if attached cli as al_cli then
				l_project := option_or (al_cli, "project", ".")
				if facade.install_skill (l_project, executable_path) then
					io.put_string ("Claude Code skill installed: " + l_project
						+ "/.claude/skills/graphify-eiffel/SKILL.md%N")
					io.put_string ("Claude will now prefer graph queries for structural questions.%N")
				else
					io.put_string ("INSTALL FAILED: " + facade.last_error + "%N")
					die (Exit_not_found)
				end
			end
		end

feature {NONE} -- Helpers

	load_graph (a_cli: SIMPLE_CLI): BOOLEAN
			-- Load the graph selected by --graph or defaults; report failure.
		local
			l_explicit: STRING
		do
			l_explicit := option_or (a_cli, "graph", "")
			if l_explicit.is_empty then
				Result := facade.load_default (".")
			else
				Result := facade.load (l_explicit)
			end
			if not Result then
				io.put_string ("GRAPH NOT LOADED: " + facade.last_error + "%N")
				io.put_string ("Run `simple_graphify build <path>` first, or pass --graph <file>.%N")
				die (Exit_not_found)
			end
		end

	graph_path_of (a_cli: SIMPLE_CLI): STRING
			-- Explicit --graph value or the default location.
		local
			l_probe: SIMPLE_FILE
		do
			Result := option_or (a_cli, "graph", "")
			if Result.is_empty then
				create l_probe.make ("graphify-out/graph.json")
				if l_probe.found and then l_probe.is_file then
					Result := "graphify-out/graph.json"
				else
					Result := "graph.json"
				end
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	sub_argument (a_index: INTEGER; a_default: STRING): STRING
			-- `a_index`-th positional argument after the command; `a_default` when absent.
		require
			index_positive: a_index >= 1
		local
			l_args: LIST [STRING]
		do
			Result := a_default
			if attached cli as al_cli then
				l_args := al_cli.arguments_after_command
				if l_args.count >= a_index then
					Result := l_args.i_th (a_index)
				end
			end
		ensure
			result_attached: Result /= Void
		end

	option_or (a_cli: SIMPLE_CLI; a_name, a_default: STRING): STRING
			-- Option value or `a_default`.
		do
			if attached a_cli.value_of (a_name) as al_value then
				Result := al_value
			else
				Result := a_default
			end
		ensure
			result_attached: Result /= Void
		end

	option_integer (a_cli: SIMPLE_CLI; a_name: STRING; a_default: INTEGER): INTEGER
			-- Integer option value or `a_default`.
		local
			l_text: STRING
		do
			l_text := option_or (a_cli, a_name, "")
			if not l_text.is_empty and then l_text.is_integer then
				Result := l_text.to_integer
			else
				Result := a_default
			end
		end

	executable_path: STRING
			-- Absolute path of this executable.
		local
			l_env: EXECUTION_ENVIRONMENT
			l_args: ARGUMENTS_32
		do
			create l_env
			create l_args
			Result := normalized_path (l_args.command_name)
			if not Result.has ('/') then
				Result := normalized_path (l_env.current_working_path.name) + "/" + Result
			end
		ensure
			result_not_empty: not Result.is_empty
		end

	print_commands
			-- Command overview.
		do
			io.put_string ("[
Commands:
  build <path>            Build knowledge graph (writes <path>/graphify-out/)
  query "question"        Answer a structural question from the graph
  explain <NAME>          Show one node with all its connections
  path <A> <B>            Shortest connection between two nodes
  stats                   Graph statistics
  report                  Re-emit GRAPH_REPORT.md to stdout
  annotate <edges.json>   Merge assistant-inferred edges (tagged inferred)
  install                 Install the Claude Code skill for this project
  version                 Show version

Options:
  --out DIR       build: output directory (default <path>/graphify-out)
  --exclude NAMES build: comma-separated directory names to skip
  --mode deep     build: add feature-level nodes
  --no-docs       build: skip markdown scanning
  --full-deps     build: include ISE/Gobo external dependencies
  --graph FILE    query commands: explicit graph.json location
  --hops N        query: neighborhood expansion (default 1)
  --limit N       query: max matched nodes (default 30)
  --project DIR   install: target project (default .)

]")
		end

feature {NONE} -- Constants

	Version: STRING = "1.0.0"
			-- Tool version.

	Exit_usage: INTEGER = 1
	Exit_not_found: INTEGER = 2
	Exit_no_content: INTEGER = 3
	Exit_annotate_failed: INTEGER = 4
			-- Exit codes per specification.

end
