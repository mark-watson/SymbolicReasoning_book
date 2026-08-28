# Deductive Synthesis & Constraint-Based Methods - Examples

This directory contains example code and demonstrations for Chapter 4, covering:

- **Deductive Synthesis**: Theorem proving approaches to program construction
- **Constraint Solving**: SAT and SMT solver integration for synthesis
- **CEGIS**: Counter-Example Guided Inductive Synthesis loops
- **Syntax-Guided Synthesis**: Grammar-constrained synthesis with templates and sketches

These examples use plain Racket to demonstrate deductive and constraint-based synthesis techniques, implementing small versions of the algorithms by hand so the search and verification logic is visible.

## Files

- `01-proof-based-synthesis.rkt` - Sequent-style proof search with program extraction (Curry-Howard)
- `02-smt-constraints.rkt` - Constraint solving over a program template (`f(x) = a*x + b`)
- `03-cegis.rkt` - Counter-Example Guided Inductive Synthesis loop
- `04-sygus-sketch.rkt` - SyGuS grammar enumeration and sketch completion

## Running

```bash
racket 01-proof-based-synthesis.rkt
racket 02-smt-constraints.rkt
racket 03-cegis.rkt
racket 04-sygus-sketch.rkt
```
