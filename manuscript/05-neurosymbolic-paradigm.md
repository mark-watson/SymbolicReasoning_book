# Neurosymbolic Architectures & Algorithms

Building on the neurosymbolic paradigm, researchers have developed specific architectures that tightly integrate neural networks with symbolic reasoning. This chapter examines four influential approaches that have demonstrated how to combine learning and logic in practical systems.

## Logic Tensor Networks (LTN)

Logic Tensor Networks bridge first-order logic and deep learning by interpreting logical formulas as tensor computations. In an LTN:

- **Constants** are represented as vectors in a feature space
- **Predicates** are functions from tensor tuples to truth values in [0,1]
- **Logical operators** are implemented using differentiable t-norms (e.g., product, Łukasiewicz)

The key insight is that logical inference can be approximated as differentiable tensor operations, enabling end-to-end training. LTNs have been applied to knowledge base completion, semantic image interpretation, and relational reasoning tasks.

## Logical Neural Networks (LNN)

Logical Neural Networks take a different approach: they construct neural networks whose structure directly encodes logical formulas. Each neuron in an LNN corresponds to a logical subformula, and the network's computation graph mirrors the formula's parse tree.

LNNs use:
- **Real-valued weights** for neurons representing logical atoms
- **Constrained activations** that output values in [0,1]
- **Specialized activation functions** for different logical connectives

The result is a network that can be trained with gradient descent while performing logical inference. LNNs support both forward inference (deriving consequences) and backward inference (abduction), making them versatile for various reasoning tasks.

## NeurASP: Integrating Answer Set Programming with Neural Networks

NeurASP combines the declarative logic programming paradigm of Answer Set Programming (ASP) with neural networks. ASP is particularly well-suited for problems involving constraints, defaults, and optimization, but traditional ASP solvers cannot leverage statistical learning from data.

NeurASP works by:
1. **Neural Networks as Oracles**: Use neural networks to compute probabilities of atomic facts
2. **ASP Programs with Probabilistic Facts**: Embed these probabilities into ASP programs
3. **Gradient Computation**: Backpropagate through the ASP solving process to train the neural networks

This integration allows NeurASP to handle problems that require both perception (processing raw data) and reasoning (satisfying complex constraints), such as visual question answering with compositional structure.

## Differentiable Inductive Logic Programming (∂ILP)

Inductive Logic Programming (ILP) learns logic programs from examples. Traditional ILP uses symbolic search and is not differentiable. ∂ILP makes ILP differentiable by:

- **Neural Network Implementation**: Implementing the ILP search process as a differentiable neural network
- **Soft Unification**: Using continuous relaxations of unification to enable gradient flow
- **Memory-Augmented Networks**: Employ external memory to store and retrieve logical clauses

∂ILP can learn interpretable logical rules from noisy data while maintaining the ability to generalize systematically. The learned programs are explicit, human-readable, and can be verified against domain knowledge.

---

These architectures demonstrate the diversity of approaches in neurosymbolic AI. Each offers a different trade-off between learning capability, reasoning power, and scalability. The next part of this book explores advanced topics including generalization, skill acquisition, and applications to scientific discovery.
