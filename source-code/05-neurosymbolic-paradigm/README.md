# The Neurosymbolic Paradigm - Examples

This directory contains example code and demonstrations for Chapter 5, covering:

- **Why Deep Learning Alone is Insufficient**: A perceptron trained on linear data fails on XOR and extrapolation
- **Neural-Symbolic Integration**: A mock perceptual digit recognizer feeding a symbolic addition layer (MNIST digit addition task)
- **Differentiable Reasoning**: Soft logic with t-norm connectives; gradient ascent on a knowledge base's satisfaction learns the inference human -> mortal
- **Compositional Reasoning Case Study**: Pure neural memorization vs. enumerative program synthesis from a single example

These examples use plain Racket and implement small versions of the ideas by hand so the reasoning and learning logic is visible.

## Files

- `01-why-deep-learning-insufficient.rkt` - Perceptron on a linear task, extrapolation failure, and the XOR limitation
- `02-neural-symbolic-synergy.rkt` - MNIST digit-addition: pure memorization vs. neural perception + symbolic addition
- `03-differentiable-reasoning.rkt` - Soft logic (t-norm AND, Reichenbach implication) with gradient-based inference
- `04-compositional-reasoning-case-study.rkt` - Program synthesis vs. memorization on a one-shot task

## Running

```bash
racket 01-why-deep-learning-insufficient.rkt
racket 02-neural-symbolic-synergy.rkt
racket 03-differentiable-reasoning.rkt
racket 04-compositional-reasoning-case-study.rkt
```
