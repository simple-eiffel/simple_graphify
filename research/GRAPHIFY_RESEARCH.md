# Graphify Research Summary

**Date:** 2026-07-18
**Source:** https://github.com/Graphify-Labs/graphify (MIT, ~76k stars), graphify.com docs/blog

## What Graphify Is

Graphify turns a project folder (code, docs, PDFs, images, video) into a queryable
knowledge graph so AI coding assistants answer questions from a pre-built map instead
of grepping raw files. Reported token savings per query: ~2.5x-70x depending on corpus.

## Architecture (upstream)

Three-pass extraction pipeline:

| Pass | Input | Method | LLM? |
|------|-------|--------|------|
| 1 | Code | tree-sitter AST: classes, functions, imports, call graphs, inline comments | No (fully local, deterministic) |
| 2 | Audio/video | faster-whisper transcription | No |
| 3 | Docs/PDF/images | Semantic concept extraction | Yes (configured backend) |

**Graph model:**
- **Nodes** — code entities (class/function/variable), documents, concepts, design decisions
- **Edges** — typed (`calls`, `imports`, `inherits`, `references`, `uses`, `mixes_in`) with
  confidence tags: `EXTRACTED` (explicit in source), `INFERRED` (derived), `AMBIGUOUS` (uncertain)
- **Communities** — Leiden algorithm clusters with generated labels (subsystems)
- **God nodes** — highest-degree hubs, surfaced as critical integration points
- **Design rationale** — comments tagged `# NOTE:` / `# WHY:` become first-class nodes

**Outputs** (`graphify-out/`): `graph.json` (persistent graph), `graph.html` (interactive
vis.js visualization), `GRAPH_REPORT.md` (god nodes, surprising connections, suggested
questions), optional `wiki/` and `obsidian/` exports, `cache/` (SHA256 change detection).

**CLI:** `graphify .` (build), `graphify query "q"` (scoped subgraph), `graphify path A B`
(shortest connection), `graphify explain "Entity"` (node + all connections),
`--update` (incremental), `--mode deep`, `--watch`, `--wiki`, `--obsidian`, `--neo4j`.

**Assistant integration:** `graphify install` registers a skill/slash command
(`/graphify`) + MCP server (~10 tools: query_graph, get_node, shortest_path, ...).
PreToolUse hooks nudge the assistant toward graph queries instead of grep.
`graphify hook install` adds a post-commit git hook for zero-cost AST-only rebuilds.

## Adaptation Decisions for simple_graphify (Eiffel)

1. **Pass 1 replacement:** tree-sitter → `simple_eiffel_parser` (Gobo-backed with
   lightweight fallback) + ECF parsing via `simple_xml`. Eiffel gives us MORE than
   tree-sitter: contracts (require/ensure/invariant), deferred/expanded status,
   rename/redefine adaptation, creation procedures, cluster/library topology.
2. **Pass 2 (audio/video):** out of scope — no Eiffel repo carries meaningful A/V.
3. **Pass 3 (LLM semantic pass):** the EXE stays 100% deterministic/local. Semantic
   enrichment is delegated to Claude Code itself via the installed skill: Claude can
   run `annotate` to merge its own inferred edges (tagged `inferred`) into graph.json.
   This mirrors Graphify's "uses your assistant's model" design without embedding an
   API client in the tool.
4. **Communities:** Leiden → deterministic label propagation (no external deps,
   reproducible output = git-diffable graph.json, matching Graphify's team workflow).
5. **Visualization:** vis.js CDN → fully self-contained `graph.html` (inline canvas
   force-directed renderer, zero network access).
6. **Skill:** ships a Claude Code skill teaching build/query/explain/path usage,
   installed by `simple_graphify install`.

## Reused simple_* Libraries (verified APIs)

| Library | Used for | Key API |
|---------|----------|---------|
| simple_eiffel_parser | .e structural parse | `SIMPLE_EIFFEL_PARSER.parse_file: EIFFEL_AST`, `EIFFEL_CLASS_NODE` (name/parents/features/creators/header_comment/is_deferred), `EIFFEL_FEATURE_NODE` (kind/return_type/arguments/locals/pre/postcondition), `EIFFEL_PARENT_NODE` (parent_name/renames/redefines) |
| simple_xml | ECF parsing | `SIMPLE_XML_QUICK.parse_file: SIMPLE_XML_DOCUMENT`, `SIMPLE_XML_ELEMENT.elements/attr` |
| simple_json | graph.json re-load | `SIMPLE_JSON_QUICK.parse_object`, `SIMPLE_JSON_OBJECT/ARRAY` |
| simple_graph | path algorithms | `SIMPLE_GRAPH [STRING]` add_node/add_edge/dijkstra/bfs/degree |
| simple_cli | argument parsing | `SIMPLE_CLI` flag/option_def/parse/first_arg/positional_args |
| simple_file | fs traversal + IO | `SIMPLE_FILE` content/set_content/files/directories/files_with_extension |
| simple_datetime | timestamps | now/ISO formatting |
| simple_testing | test suite | TEST_SET_BASE pattern |
