# Changelog

## 1.1.0 — 2026-07-18

### Changed
- **Contract depth is now structural.** Per-feature require/ensure clauses and
  per-class invariant clauses are counted from the full Gobo AST
  (`ET_ASSERTIONS.count` via `ET_EIFFEL_PARSER`) instead of counting
  require/ensure keyword lines. A `require` block with three tagged assertions
  now scores 3, not 1. New class metric `contract_clauses` (require + ensure +
  invariant) and `invariant_clauses`; the Contract Coverage report uses them.
  Keyword-line counting remains only as a floor for files Gobo cannot parse.

### Fixed
- Gobo analysis now excludes `free_elks` and `thread` (verbatim ISE copies),
  matching how Gobo is excluded from the ISE analysis. Removing them drops 413
  classes and unseats `BOOLEAN` as Gobo's top god node (it was ELKS, not Gobo).
- `architecture.html` corrected: the Gobo parser does carry comments (via
  `ET_DECORATED_AST_FACTORY.set_keep_all_comments`) and contracts (native AST
  nodes); the earlier "shallow preparse" claim wrongly implied otherwise.

_Both corrections courtesy of Eric Bezault (author of Gobo)._

## 1.0.0 — 2026-07-18

Initial release.

- Three-pass deterministic extraction: ECF topology (string-scan, namespace-proof),
  Eiffel class structure via simple_eiffel_parser (inheritance, contracts, flags,
  creators), comment-aware supplier scan (uses/creates/mentions), rationale mining
  (NOTE:/WHY:/TODO:), markdown document references.
- Analysis: degrees, deterministic label-propagation communities with
  library-majority labels, god nodes, surprising cross-community connections.
- Artifacts: graph.json (stable ordering), GRAPH_REPORT.md (incl. DbC contract
  coverage), self-contained graph.html, graph.dot (simple_graphviz).
- CLI: build / query / explain / path / stats / report / annotate / install.
- Claude Code skill (graphify-eiffel) installed via `install`; assistant-driven
  semantic enrichment via `annotate` (edges tagged inferred).
- Deep mode: feature-level nodes with signature uses edges.
- 24 tests against the committed toy_project fixture.

Deviations from spec v1.0 (recorded during implementation):
- ECF parsing uses tolerant tag/attribute string scanning instead of simple_xml
  (namespace-proof; precedent: claude_tools uuid scan).
- Community detection excludes contains/depends_on edges so communities emerge
  from usage topology rather than folder structure.
- Added graph.dot artifact (simple_graphviz) beyond the spec'd three outputs.
