# simple_graphify

[Documentation](https://simple-eiffel.github.io/simple_graphify/) •
[GitHub](https://github.com/simple-eiffel/simple_graphify) •
[Issues](https://github.com/simple-eiffel/simple_graphify/issues)

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Eiffel 25.02](https://img.shields.io/badge/Eiffel-25.02-purple.svg)
![DBC: Contracts](https://img.shields.io/badge/DBC-Contracts-green.svg)
![Windows: tests pass](https://img.shields.io/badge/Windows-tests%20pass-0078D6?logo=windows&logoColor=white) ![Linux: tests pass](https://img.shields.io/badge/Linux-tests%20pass-FCC624?logo=linux&logoColor=black) ![macOS: tests pass](https://img.shields.io/badge/macOS-tests%20pass-000000?logo=apple&logoColor=white)

Turn any Eiffel project into a queryable knowledge graph — Graphify for Eiffel + Claude Code.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem. Inspired by
[Graphify](https://github.com/Graphify-Labs/graphify) (MIT), rebuilt natively in Eiffel.

## Status

✅ **Production Ready** — v1.0.0
- 24 tests passing, 100% pass rate
- Deterministic local extraction (no LLM, no network), typed confidence-tagged edges, DbC coverage reporting
- Design by Contract throughout, void-safe, SCOOP-compatible

## Quick Start

```bash
simple_graphify build D:/prod/my_lib      # -> graphify-out/: graph.json, GRAPH_REPORT.md, graph.html, graph.dot
simple_graphify query "how does the cache work"
simple_graphify explain MY_CLASS
simple_graphify install                   # Claude Code answers structural questions from the graph
```

For complete documentation, see [our docs site](https://simple-eiffel.github.io/simple_graphify/).

## Features

- Knowledge graph of libraries, clusters, classes, features, documents, and design rationale
- Typed edges (inherits/uses/creates/contains/depends_on/references/mentions) tagged extracted/inferred/ambiguous
- Communities, god nodes, surprising connections, contract-coverage report
- Token-efficient query CLI + Claude Code skill; assistant-inferred edges via `annotate`

For details, see the [User Guide](https://simple-eiffel.github.io/simple_graphify/user-guide.html).

## Installation

```bash
# Add to your ECF:
<library name="simple_graphify" location="$SIMPLE_EIFFEL/simple_graphify/simple_graphify.ecf"/>
```

## License

MIT License - See LICENSE file

## Support

- **Docs:** https://simple-eiffel.github.io/simple_graphify/
- **GitHub:** https://github.com/simple-eiffel/simple_graphify
- **Issues:** https://github.com/simple-eiffel/simple_graphify/issues
