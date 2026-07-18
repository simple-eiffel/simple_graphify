# simple_graphify — Specification v1.0

**Knowledge-graph extractor for Eiffel projects, integrated with Claude Code.**
Eiffel-native reimplementation of Graphify (github.com/Graphify-Labs/graphify).

**Date:** 2026-07-18 · **Status:** APPROVED FOR IMPLEMENTATION

---

## 1. Mission

Turn any Eiffel project directory (ECFs, `.e` sources, markdown docs) into a
persistent, queryable knowledge graph so that Claude Code answers structural
questions from a pre-built map instead of grepping files — fewer tokens, more
accurate answers, durable cross-session memory.

**Non-goals (v1):** audio/video transcription, PDF/image analysis, embeddings,
MCP server, file watching, Neo4j export, incremental hash-cache updates
(full rebuild is deterministic and fast enough), Obsidian export.

## 2. Guarantees

1. **Deterministic:** identical input tree ⇒ byte-identical `graph.json`
   (stable ordering everywhere; no wall-clock data inside `nodes`/`edges`/
   `communities`; timestamp only in the header `generated_at` field).
2. **Fully local:** no network, no LLM calls inside the EXE.
3. **Void-safe, SCOOP-compatible, contracted** per ecosystem standards.
4. **Token-efficient query output:** compact markdown, hard node/edge caps.

## 3. Extraction Pipeline (three passes)

### Pass 1 — Structure (deterministic)

**1a. ECF scan.** Every `*.ecf` under root (excluding `EIFGENs`, hidden dirs):
- Node `library:<system-name>` — from `<system name=...>`; description from `<description>`.
- Edge `library:X --depends_on--> library:Y` for each `<library location=...>`
  whose `.ecf` basename resolves to a known name (extracted from the location
  path's file stem). Confidence `extracted`. External (ISE/Gobo) targets get
  nodes with flag `external` only when `--full-deps` is set; by default only
  `simple_*`/project-local libraries become nodes (noise control).
- Edge `library:X --contains--> cluster:<X>/<cluster-name>` per `<cluster>`.

**1b. Class scan.** Every `*.e` under root, excluding `EIFGENs/`, `_deprecated/`,
hidden dirs, and `*.bak`/`*.orig`. Parsed with `SIMPLE_EIFFEL_PARSER.parse_file`.
Per parsed class:
- Node `class:<NAME>` — file (root-relative, `/` separators), line, flags
  (`deferred`, `expanded`, `frozen`), description = first line of header
  comment/note description (≤200 chars), metrics:
  `features`, `queries`, `commands`, `attributes`, `preconditions`,
  `postconditions`, `loc` (file line count), `creators` count.
- Edge `class:A --inherits--> class:B` per parent (confidence `extracted`;
  `why` = "inherit" plus `renames: N, redefines: M` when nonzero).
- Edge `cluster:<lib>/<cluster> --contains--> class:A` when the file lies under
  a scanned cluster directory; else `library:<lib> --contains--> class:A`
  for the nearest enclosing ECF's library node.
- **Supplier scan** (raw text, comment/string-stripped): every ALL_CAPS
  identifier token (regex `[A-Z][A-Z0-9_]{2,}`) that matches another scanned
  class name ⇒ edge `class:A --uses--> class:B`, weight = occurrence count,
  line = first occurrence, confidence `extracted`. Tokens found ONLY in
  comments ⇒ confidence `inferred`, kind `mentions`. Self-references and
  parent duplicates are suppressed (inherits wins over uses).
  Occurrences as `create {B}` or `{B}.` ⇒ kind `creates` (subsumes `uses`
  for that pair when creation is detected).
- **Rationale mining:** comment lines matching `-- NOTE:`, `-- WHY:`,
  `-- TODO:` ⇒ node `tag:<CLASS>#<n>` (kind `rationale`, description = text
  ≤200 chars, line) + edge `class:A --mentions--> tag:...` (`extracted`).

**1c. Feature nodes (deep mode only, `--mode deep`).** Per feature of each
class: node `feature:<CLASS>.<name>` (kind `feature`, line, description =
header comment, flags `deferred`/`once`/`attribute`/`external`, metrics:
`arguments`, `has_precondition`, `has_postcondition`) + edge
`class:C --contains--> feature:C.f`. Feature signature types that match known
classes ⇒ `feature:C.f --uses--> class:T` (`extracted`, why = "signature").

### Pass 2 — Documents (deterministic)

Every `*.md` (excluding `EIFGENs`, `node_modules`, hidden dirs):
- Node `doc:<relative/path.md>` — kind `document`, description = first `# `
  heading or first non-empty line (≤200 chars), metrics: `lines`.
- Scan text for known class names (same ALL_CAPS matching) ⇒ edge
  `doc:D --references--> class:C` (weight = count, confidence `extracted`).
- Scan for known library names (word match of scanned system names, e.g.
  `simple_http`) ⇒ `doc:D --references--> library:L`.

### Pass 3 — Analysis (deterministic)

- **Degree:** undirected degree per node (in+out, parallel kinds counted once
  per (from,to,kind)).
- **Communities:** synchronous label propagation on the undirected projection.
  Init: each node's label = own ordinal in id-sorted order. Iterate ≤20
  rounds; each node adopts the most frequent neighbor label, ties broken by
  smallest label; stop at fixpoint. Isolated nodes form singleton communities.
  Communities renumbered 1..K by descending size (ties: smallest member id).
  **Label:** most frequent library membership among members ("simple_http
  core"); fallback: highest-degree member's label + " group".
- **God nodes:** top 10 by degree (ties: id order), excluding `document` and
  `rationale` nodes.
- **Surprising connections:** edges whose endpoints lie in different
  communities, ranked by `min(degree(a), degree(b))` ascending (i.e. links
  between otherwise-peripheral nodes across subsystems), doc→class edges
  ranked before class→class at equal score. Top 10.

### LLM enrichment (delegated to Claude Code)

`simple_graphify annotate <edges.json>` merges assistant-generated edges into
an existing graph.json. Input schema: `{"edges":[{"from","to","kind","why"}]}`.
All merged edges are forced `confidence: "inferred"`; unknown endpoints are
rejected with a warning; duplicates update `why` only. This is how the
"semantic pass" happens — Claude reads docs, decides connections, records them.

## 4. graph.json Schema (v1)

```json
{
  "schema_version": "1.0",
  "generator": "simple_graphify 1.0.0",
  "root": "D:/prod/simple_http",
  "generated_at": "2026-07-18T14:03:22",
  "mode": "standard",
  "stats": { "nodes": 214, "edges": 897, "communities": 9,
             "files_scanned": 87, "classes": 61, "documents": 12 },
  "nodes": [
    { "id": "class:SIMPLE_HTTP", "kind": "class", "label": "SIMPLE_HTTP",
      "file": "src/simple_http.e", "line": 14, "community": 1, "degree": 37,
      "flags": [], "description": "HTTP client facade ...",
      "metrics": { "features": 42, "queries": 25, "commands": 14,
                   "attributes": 3, "preconditions": 30,
                   "postconditions": 22, "loc": 1180, "creators": 1 } }
  ],
  "edges": [
    { "from": "class:SIMPLE_HTTP", "to": "class:SIMPLE_HTTP_RESPONSE",
      "kind": "uses", "confidence": "extracted", "weight": 11,
      "line": 210, "why": "supplier reference" }
  ],
  "communities": [
    { "id": 1, "label": "simple_http core", "size": 38,
      "members_sample": ["class:SIMPLE_HTTP", "..."] }
  ],
  "god_nodes": ["class:SIMPLE_HTTP", "..."],
  "surprising": [
    { "from": "doc:docs/design.md", "to": "class:HTTP_COOKIE_JAR",
      "kind": "references", "reason": "cross-community: docs ↔ cookies" }
  ]
}
```

Node kinds: `library | cluster | class | feature | document | rationale`.
Edge kinds: `contains | depends_on | inherits | uses | creates | references | mentions`.
Confidence: `extracted | inferred | ambiguous`.
Ordering: nodes sorted by id; edges by (from, to, kind); `members_sample` ≤ 8.
All strings JSON-escaped; paths use `/`.

## 5. CLI (`simple_graphify.exe`)

```
simple_graphify build <path> [--out DIR] [--mode standard|deep] [--no-docs] [--full-deps] [--quiet]
simple_graphify query "<question>" [--graph FILE] [--hops N] [--limit N]
simple_graphify explain <NODE-OR-NAME> [--graph FILE]
simple_graphify path <A> <B> [--graph FILE]
simple_graphify stats [--graph FILE]
simple_graphify report [--graph FILE]          # re-emit GRAPH_REPORT.md to stdout
simple_graphify annotate <edges.json> [--graph FILE]
simple_graphify install [--project DIR]        # write Claude Code skill
simple_graphify version | --help
```

Defaults: `--out` = `<path>/graphify-out`; `--graph` = `./graphify-out/graph.json`
(then `./graph.json`); `--hops 1`; `--limit 30`.

**Exit codes:** 0 success; 1 usage error; 2 graph/file not found; 3 build
found no Eiffel content; 4 annotate rejected all edges.

**`build`** writes `graph.json`, `GRAPH_REPORT.md`, `graph.html` into out dir,
prints a summary (files, nodes, edges, communities, god nodes, out paths).

**`query`** — name resolution then scoring:
- Tokenize question (lowercase, split non-alphanumerics, drop stopwords + tokens < 3 chars).
- Score nodes: exact id/label match +100; label substring +60; token equals
  label word +40; token in description +15; token in file path +10.
  Weight doubles for `class` nodes.
- Take top `--limit` scored nodes (score > 0), expand `--hops` hop
  neighborhood (both directions), cap total at 3× limit.
- Emit markdown: matched nodes (label, kind, file:line, description, top
  metrics), then grouped edges `A —kind→ B (confidence)`, then relevant
  communities. Footer: totals + "refine with explain/path".
- No match ⇒ suggest 5 closest labels (substring distance), exit 0.

**`explain`** — resolve node by exact id, exact label, then unique
case-insensitive substring (ambiguity lists candidates). Output: full node
record + ALL edges grouped by kind/direction + community label + god-node rank.

**`path`** — resolve both endpoints, undirected Dijkstra (weight 1 per edge);
print hop chain with edge kind + confidence per hop, or "no path".

**`stats`** — header stats + per-kind node/edge counts + top 10 degrees.

## 6. GRAPH_REPORT.md Layout

```
# Knowledge Graph Report — <root name>
Generated: <ts> · Mode: standard · simple_graphify 1.0.0

## Summary            (files, classes, docs, nodes, edges, communities table)
## God Nodes          (rank, node, kind, degree, description)
## Communities        (id, label, size, sample members)
## Surprising Connections   (from —kind→ to + reason)
## Contract Coverage  (Eiffel-specific: % classes with invariants…, top
                       contracted classes, contract-free classes list ≤15)
## Suggested Questions (6 generated from god nodes/communities, e.g.
   "What depends on SIMPLE_HTTP?", "How do <community A> and <B> connect?")
## How to Query       (CLI cheat-sheet block)
```

## 7. graph.html

Single self-contained file: embedded graph JSON + inline JS canvas
force-directed layout (repulsion + spring along edges, ~300 iterations,
deterministic seed from node ids). Features: pan/zoom, node hover tooltip
(label/kind/degree/community), click → side panel (description, metrics,
edges), text search box (highlight matches), community coloring (12-color
palette cycling), kind-based node shapes (class=circle, library=large ring,
document=square, rationale=diamond, feature=small dot). No external requests.

## 8. Claude Code Integration

`simple_graphify install` writes `.claude/skills/graphify-eiffel/SKILL.md`
into the target project (default: cwd; `--project DIR` overrides):

- Frontmatter: name `graphify-eiffel`, description triggering on "graphify",
  "knowledge graph", "how is X wired/connected", "what depends on".
- Body teaches Claude: run `build` once per repo (or when structure shifted);
  ALWAYS try `query`/`explain`/`path` before Glob/Grep for structural
  questions; how to read confidence tags; how to `annotate` semantic edges
  it infers from docs; exact command syntax with the absolute exe path.

## 9. Architecture

```
src/
  simple_graphify.e        -- Facade: build/load/query/explain/path/annotate
  graphify_node.e          -- id, kind, label, file, line, flags, description,
                              metrics (HASH_TABLE [INTEGER, STRING]), community, degree
  graphify_edge.e          -- from_id, to_id, kind, confidence, weight, line, why
  graphify_graph.e         -- node table, edge list, adjacency, degree calc,
                              undirected shortest path (via SIMPLE_GRAPH), sorting
  graphify_ecf_scanner.e   -- pass 1a (simple_xml)
  graphify_class_scanner.e -- pass 1b/1c (simple_eiffel_parser + supplier scan)
  graphify_doc_scanner.e   -- pass 2
  graphify_analyzer.e      -- pass 3: communities, god nodes, surprising
  graphify_builder.e       -- orchestrates passes over a directory tree
  graphify_json_io.e       -- serialize (hand-emitted, escaped) / load (simple_json)
  graphify_report.e        -- GRAPH_REPORT.md generator
  graphify_html.e          -- graph.html emitter (template + embedded JSON)
  graphify_query.e         -- scoring, neighborhood, markdown rendering
  graphify_skill_writer.e  -- install command payload
app/
  graphify_app.e           -- root class; simple_cli dispatch
test/
  test_app.e, lib_tests.e, graphify_test_set.e (+ fixtures in data/input)
```

Every class: full contracts, void-safe, SCOOP-compatible types only.

## 10. ECF Targets

- `simple_graphify` — library target (src cluster), concurrency scoop,
  void_safety all. Deps: base, simple_file, simple_xml, simple_json,
  simple_cli, simple_graph, simple_datetime, simple_eiffel_parser (+ its
  transitive gobo_* requirement handled by that library's ECF).
- `simple_graphify_tests` — extends library; root TEST_APP.make;
  executable_name `test_app`; + simple_testing.
- `simple_graphify_app` — extends library; root GRAPHIFY_APP.make;
  executable_name `simple_graphify`; console app.

Binaries: `bin/test_app.exe` (finalized -keep), `bin/simple_graphify.exe`
(finalized). Per BUILD_STANDARDS.md.

## 11. Test Plan

Fixture: `data/input/toy_project/` — a miniature Eiffel project committed to
the repo: 1 ECF (`toy.ecf`, two clusters), 5 classes (inheritance chain,
supplier refs, `create {X}`, deferred class, NOTE:/WHY: comments, contracts),
2 markdown docs referencing classes. Known expected counts.

Unit/integration tests (≥18):
1. ECF scanner: library node + depends_on + cluster nodes.
2. Class scanner: class count, flags, inherits edges, description extraction.
3. Supplier scan: uses edge with correct weight; comment-only ⇒ mentions/inferred.
4. creates edge from `create {X}`.
5. Rationale nodes from NOTE:/WHY:.
6. Doc scanner: doc node + references edges w/ weights.
7. Metrics: feature/precondition/postcondition counts for a known class.
8. Analyzer: god node = expected hub; communities cover all nodes; labels non-empty.
9. Determinism: build twice ⇒ identical serialization (minus generated_at).
10. JSON round-trip: write → load → node/edge/community counts equal.
11. Query: hit on class name; miss suggests candidates; limit respected.
12. Explain: resolves by substring; ambiguous name reports candidates.
13. Path: known 2-hop chain found; disconnected pair ⇒ "no path".
14. Annotate: valid edge merged as inferred; unknown endpoint rejected.
15. Report: contains all required section headers.
16. HTML: contains embedded JSON marker + canvas element; no `http`/`https` URLs.
17. Deep mode: feature nodes exist, contains edges present.
18. Empty/no-Eiffel dir ⇒ build exit 3 semantics (status code surfaced by facade).

End-to-end acceptance (manual, evidence in `reports/`):
- `build` on a real library (e.g. `simple_json` or `simple_http`): completes,
  plausible god nodes, non-trivial communities; `query`, `explain`, `path`
  produce useful compact markdown; `graph.html` renders standalone.

## 12. Performance Targets

- 100-file library: build < 30 s (Gobo parse dominates; fallback parser on error).
- query/explain/path on 5k-node graph: < 2 s including JSON load.
- graph.json for 300-file repo: < 5 MB.

## 13. Risks

| Risk | Mitigation |
|------|-----------|
| Gobo parser chokes on odd files | simple_eiffel_parser auto-falls back to lightweight parser; scanner also try-catches per file and records a warning, never aborts the build |
| ALL_CAPS scan false positives (keywords like RESULT, constants) | match only against the scanned class-name set; strip comments/strings for `uses` |
| Huge graphs blow query output | hard caps (limit, 3× neighborhood cap) |
| Write-tool instability on this box | fall back to `scripts/python/write_file.py --base64` |
