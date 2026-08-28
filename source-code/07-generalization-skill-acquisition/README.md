# Generalization & Autonomous Skill Acquisition - Examples

This directory contains example code and demonstrations for Chapter 7, covering:

- **Generalization Beyond Training**: Comparing nearest-neighbor memorization with enumerative synthesis on a modular-arithmetic task (`01-generalization-beyond-training.rkt`)
- **Compositional Abstractions**: Learning and reusing macros in a tiny library‑learning setup (`02-compositional-abstractions.rkt`)
- **Test-Time Adaptation**: Online synthesis of a linear model as new examples arrive (`03-test-time-adaptation.rkt`)
- **Autonomous Skill Acquisition**: Acquiring skills from examples, composing them, and using the composed skill on new inputs (`04-skill-acquisition.rkt`)

These examples use plain Racket and implement small versions of the algorithms by hand so the search, reuse, and learning logic is visible.

## Files

- `01-generalization-beyond-training.rkt` - Nearest‑neighbor vs. grammar‑based synthesis for `(x+1) mod 4`
- `02-compositional-abstractions.rkt` - Macro learning and reuse (`double ∘ inc`) in a small composition space
- `03-test-time-adaptation.rkt` - Online synthesis of `a*x + b` as data streams in
- `04-skill-acquisition.rkt` - Skill library: learn `double`, `square`, compose into `two-x-squared`

## Running

```bash
racket 01-generalization-beyond-training.rkt
racket 02-compositional-abstractions.rkt
racket 03-test-time-adaptation.rkt
racket 04-skill-acquisition.rkt
```
