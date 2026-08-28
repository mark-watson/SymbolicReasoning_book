# Benchmarks, Evaluation, and the Path to AGI - Examples

This directory contains example code and demonstrations for Chapter 9, covering:

- **Evaluation Frameworks**: Measuring train/test accuracy, program size, and search efficiency across a benchmark suite (`01-evaluation-framework.rkt`)
- **ARC-Style Task**: A tiny 1-D analogue of the Abstraction and Reasoning Corpus, where 2 examples define a transformation rule and a held-out grid tests generalization (`02-arc-style-task.rkt`)
- **SCAN-Style Compositional Generalization**: Training on short commands, testing on longer compositions; a recursive parser closes the gap that a length-bounded synthesizer cannot (`03-compositional-benchmark.rkt`)
- **Generalization-Gap Leaderboard**: Scoring nearest-neighbor memorization, a simple grammar, and a richer grammar on a battery of tasks (`04-generalization-gap-leaderboard.rkt`)

These examples use plain Racket so the evaluation harnesses, ranking metrics, and synthesis strategies are all explicit.

## Files

- `01-evaluation-framework.rkt` - Per-task and aggregate metrics across a 5-task suite
- `02-arc-style-task.rkt` - Reverse-the-list rule over 1-D grids, discovered from 2 examples
- `03-compositional-benchmark.rkt` - SCAN-like grammar; length-bounded vs. compositional parsing
- `04-generalization-gap-leaderboard.rkt` - Memorization vs. synthesis; measuring the generalization gap

## Running

```bash
racket 01-evaluation-framework.rkt
racket 02-arc-style-task.rkt
racket 03-compositional-benchmark.rkt
racket 04-generalization-gap-leaderboard.rkt
```
