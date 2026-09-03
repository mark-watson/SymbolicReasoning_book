# Introduction to Symbolic Reasoning - Examples

This directory contains example code and demonstrations for Chapter 1, covering:

- **Propositional and Predicate Logic**: `01-propositional-logic.rkt` - Basic logic operations, truth tables, and logical inference
- **Automated Theorem Proving**: `02-unification.rkt` - Unification algorithm for matching terms, `03-forward-chaining.rkt` - Forward chaining inference engine
- **Knowledge Representation**: `04-semantic-network.rkt` - Semantic network construction, querying, and inheritance
- **Search and Planning**: `05-search-algorithms.rkt` - BFS and DFS as one search parameterized by a combiner, `06-constraint-satisfaction.rkt` - backtracking CSP solver (map coloring of Australia; the same `satisfies?`/`solve-map-coloring` parameterization takes other constraint sets)

These examples use Racket Scheme to illustrate foundational symbolic reasoning concepts that underpin the program synthesis techniques explored throughout the book.

## Running the Examples

Each file is a self-contained Racket module. Run them directly:

```bash
racket 01-propositional-logic.rkt
racket 02-unification.rkt
racket 03-forward-chaining.rkt
racket 04-semantic-network.rkt
racket 05-search-algorithms.rkt
racket 06-constraint-satisfaction.rkt
```

The examples demonstrate key symbolic AI techniques that provide the foundation for the program synthesis methods explored in later chapters.
