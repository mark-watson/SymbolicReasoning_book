# Program Synthesis for Scientific Discovery - Examples

This directory contains example code and demonstrations for Chapter 8, covering:

- **Automated Hypothesis Generation**: Enumerating candidate physical laws over a formula grammar and ranking by fit plus simplicity (`01-hypothesis-generation.rkt`)
- **Data-Efficient Learning**: Recovering the free-fall law `d = (1/2) g t^2` from only four noisy measurements (`02-data-efficient-learning.rkt`)
- **Causal and Temporal Reasoning**: Pearl-style `do(...)` interventions in a three-node causal model with counterfactual queries (`03-causal-reasoning.rkt`)
- **Case Study — Equation Discovery**: Rediscovering Kepler's third law `T^2 = a^3` from noisy observations, with parsimony-driven ranking and held-out verification (`04-equation-discovery-kepler.rkt`)

These examples use plain Racket and implement the search, scoring, and intervention logic from scratch so the reasoning is visible.

## Files

- `01-hypothesis-generation.rkt` - Enumerate formula hypotheses and rank by fit + simplicity (Ohm's law toy domain)
- `02-data-efficient-learning.rkt` - Identify `d = (1/2) g t^2` from just 4 points in a physics grammar
- `03-causal-reasoning.rkt` - Vaccinate/infection/hospital causal chain with do-interventions and counterfactuals
- `04-equation-discovery-kepler.rkt` - Rediscover Kepler's third law with a power-law grammar and simplicity-penalized ranking

## Running

```bash
racket 01-hypothesis-generation.rkt
racket 02-data-efficient-learning.rkt
racket 03-causal-reasoning.rkt
racket 04-equation-discovery-kepler.rkt
```
