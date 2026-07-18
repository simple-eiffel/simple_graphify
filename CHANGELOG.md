# Changelog

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
