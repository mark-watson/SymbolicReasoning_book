# Neurosymbolic Architectures & Algorithms - Examples

This directory contains example code and demonstrations for Chapter 6, covering:

- **Logic Tensor Networks (LTN)**: embeddings for constants, learned predicate weights, differentiable t-norms, and gradient ascent on KB satisfaction (`01-logic-tensor-network.rkt`)
- **Logical Neural Networks (LNN)**: neurons as logical formulas (and, impl), forward evaluation plus gradient-based training of belief values (`02-logical-neural-network.rkt`)
- **NeurASP**: neural oracle produces probabilities, a mock ASP program scores rule satisfaction, and gradient ascent improves both (`03-neurasp.rkt`)
- **Differentiable ILP (∂ILP)**: softmax over candidate rules, gradient descent on a loss over positive/negative examples (`04-dilp.rkt`)

These examples use plain Racket and implement small versions of the algorithms by hand so the search, relaxation, and learning logic is visible rather than hidden inside an external solver.

## Files

- `01-logic-tensor-network.rkt` - Minimal LTN with gradient-ascent training of predicate weights
- `02-logical-neural-network.rkt` - Tiny LNN with implication/AND neurons and gradient update of an input belief
- `03-neurasp.rkt` - NeurASP-style integration of a 2-class neural classifier with a mock ASP rule set
- `04-dilp.rkt` - Differentiable ILP: softmax over rule templates, gradient descent to learn a rule weighting

## Running

```bash
racket 01-logic-tensor-network.rkt
racket 02-logical-neural-network.rkt
racket 03-neurasp.rkt
racket 04-dilp.rkt
```
