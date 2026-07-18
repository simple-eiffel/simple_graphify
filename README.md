# simple_graphify

**Knowledge graphs for Eiffel projects — Graphify, reimagined for Eiffel + Claude Code.**

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem. Inspired by
[Graphify](https://github.com/Graphify-Labs/graphify) (MIT), rebuilt natively in Eiffel.

`simple_graphify` turns any Eiffel project directory — ECFs, `.e` sources, markdown
docs — into a persistent, queryable knowledge graph. Your AI coding assistant then
answers structural questions from a pre-built map instead of grepping files:
fewer tokens, more accurate answers, durable cross-session memory.

## What you get

```
simple_graphify build D:/prod/simple_http
```

writes `graphify-out/`:

| Artifact | Purpose |
|---|---|
| `graph.json` | The persistent graph (nodes/edges/communities), deterministic and git-diffable |
| `GRAPH_REPORT.md` | God nodes, communities, surprising connections, DbC contract coverage, suggested questions |
| `graph.html` | Self-contained interactive visualization (no network, no CDN) |
| `graph.dot` | Graphviz export (render with `dot -Tsvg`) |

## The graph model

- **Nodes**: `library`, `cluster`, `class`, `feature` (deep mode), `document`,
  `rationale` (mined from `-- NOTE:` / `-- WHY:` / `-- TODO:` comments).
- **Edges** (typed): `inherits`, `uses`, `creates`, `contains`, `depends_on`,
  `references`, `mentions` — each tagged with confidence:
  `extracted` (explicit in source), `inferred` (derived), `ambiguous`.
- **Communities**: deterministic label propagation, labeled by dominant library.
- **God nodes**: the integration hubs of your codebase, ranked by degree.
- **Eiffel bonus**: per-class contract metrics (preconditions, postconditions) —
  the report includes a Design-by-Contract coverage section tree-sitter tools can't produce.

Extraction is **100% local and deterministic** — no LLM, no network, no embeddings.
Identical input produces byte-identical graphs (modulo timestamp), so `graphify-out/`
can be committed and shared with a team, exactly like upstream Graphify.

## Querying

```
simple_graphify query "how does the response cache work"   # scoped subgraph, compact markdown
simple_graphify explain SIMPLE_HTTP                        # one node + ALL its connections
simple_graphify path SIMPLE_HTTP HTTP_COOKIE_JAR           # shortest connection chain
simple_graphify stats                                      # graph overview
simple_graphify report                                     # re-emit GRAPH_REPORT.md
```

Query commands read `./graphify-out/graph.json` (or `--graph FILE`).

## Claude Code integration

```
simple_graphify install --project D:/prod/my_lib
```

installs `.claude/skills/graphify-eiffel/SKILL.md` into the project. Claude Code
then prefers graph queries over grep for structural questions ("what depends on X",
"how are A and B wired"), and knows how to rebuild after refactors.

**Claude is the semantic pass.** Upstream Graphify sends docs to an LLM backend;
here, the assistant itself enriches the graph:

```
simple_graphify annotate edges.json      # {"edges":[{"from":"class:A","to":"doc:d.md","kind":"references","why":"..."}]}
```

Merged edges are tagged `inferred` and survive future queries.

## Build options

```
simple_graphify build <path> [--out DIR] [--mode deep] [--no-docs] [--full-deps] [--quiet]
```

- `--mode deep` adds feature-level nodes with signature-derived `uses` edges.
- `--full-deps` includes ISE/Gobo external libraries as dependency nodes.

## Installation

Requires the Simple Eiffel ecosystem (`SIMPLE_EIFFEL=D:\prod`) and EiffelStudio 25.02.

```bash
cd D:/prod/simple_graphify
/d/prod/ec.sh release -config simple_graphify.ecf -target simple_graphify_app
# binary: bin/simple_graphify.exe
```

Run tests:

```bash
/d/prod/ec.sh test -config simple_graphify.ecf -target simple_graphify_tests
./bin/test_app.exe
```

## Dependencies

`simple_eiffel_parser` (Eiffel structure), `simple_graph` (path algorithms),
`simple_json` (graph re-load), `simple_cli`, `simple_file`, `simple_graphviz`
(DOT export), `simple_datetime`. ISE `base` only where no simple_* equivalent exists.

## Design

Design by Contract throughout, void-safe, SCOOP-compatible. Full specification in
`specs/SPECIFICATION.md`; upstream research in `research/GRAPHIFY_RESEARCH.md`.

## License

MIT
