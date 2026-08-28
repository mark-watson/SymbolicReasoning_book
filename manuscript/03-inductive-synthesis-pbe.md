# Deductive Synthesis & Constraint-Based Methods

While inductive synthesis infers programs from examples, deductive synthesis takes the opposite approach: it derives programs from formal specifications using logical inference. This chapter explores the powerful deductive and constraint-based techniques that have produced some of the most reliable and theoretically grounded synthesis systems.

## Deductive Synthesis using Theorem Proving

Deductive synthesis treats program synthesis as a theorem-proving task. Given a specification of the desired behavior, the goal is to construct a program that provably satisfies this specification.

The process typically involves:
1. **Specification**: Express the desired input-output relationship as a logical formula
2. **Existential Proof**: Prove that a program exists satisfying the specification (constructive proof yields the program)
3. **Program Extraction**: Extract the actual program from the proof

This approach guarantees correctness by construction. If the theorem prover succeeds, the extracted program satisfies the specification exactly. However, theorem proving is computationally expensive and often requires human guidance for non-trivial problems.

Modern deductive synthesis systems use interactive theorem provers like Coq or Isabelle, leveraging tactics and decision procedures to automate portions of the proof while allowing human insight to guide the overall strategy.

## Constraint Solving for Synthesis (SMT, SAT)

Constraint-based synthesis reduces the synthesis problem to finding a satisfying assignment to a set of logical constraints. This approach has become dominant due to the remarkable efficiency of modern SAT and SMT solvers.

- **SAT Solvers**: Determine whether a Boolean formula has a satisfying assignment
- **SMT Solvers**: Extend SAT with theories like arithmetic, arrays, and bit-vectors

The constraint-based approach works by:
1. Encoding the synthesis problem as a logical formula
2. Using the solver to find a model (satisfying assignment)
3. Decoding the model into a program

This method elegantly separates the synthesis logic from the search machinery, allowing synthesis researchers to leverage decades of advances in constraint solving technology.

## Counter-Example Guided Inductive Synthesis (CEGIS)

CEGIS combines the best of inductive and deductive synthesis in an iterative loop:

1. **Generate**: Produce a candidate program that satisfies the current set of inputs
2. **Verify**: Check if the candidate satisfies the full specification
3. **Counterexample**: If verification fails, use the counterexample as a new input-output example
4. **Repeat**: Continue until the candidate verifies or resources are exhausted

CEGIS is particularly effective because it uses verifiers to focus search on the most informative examples—the ones that actually constrain the solution space. This approach has powered many successful synthesizers, including those for bit-vector transformations and distributed protocols.

## Syntax-Guided Synthesis (SyGuS)

Syntax-Guided Synthesis adds user-provided syntactic restrictions to the synthesis problem. The specification includes not just the semantic requirements (what the program should do) but also syntactic constraints (what form the program can take).

- **Grammar-Based Constraints**: Limit the space of candidate programs using context-free grammars
- **Templates**: Restrict programs to match certain structural patterns
- **Sketching**: Provide partial programs with "holes" to fill

By constraining the search space syntactically, SyGuS makes synthesis tractable for complex domains. The approach recognizes that users often know more about the form of the solution than just its behavior, and that this knowledge should be exploited.

---

Deductive and constraint-based methods provide the theoretical foundation for program synthesis with strong correctness guarantees. The next part of this book explores how these symbolic techniques combine with neural networks to create systems that can learn and reason together.
