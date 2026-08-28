# Inductive Synthesis & Programming by Example (PBE)

Programming by Example (PBE) represents one of the most intuitive and practical approaches to program synthesis. Instead of writing formal specifications or logical descriptions of desired behavior, users provide concrete input-output examples. The synthesis system must then infer a program that correctly transforms the given inputs to the desired outputs. This chapter explores the core techniques that make PBE work.

## Enumerative Search: Bottom-Up and Top-Down

The most straightforward approach to PBE is to systematically generate and test candidate programs until finding one that satisfies all examples.

- **Bottom-Up Search**: Start with simple expressions and combine them into more complex programs. Maintain a set of "plausible" subprograms and iteratively build larger programs by composing smaller ones.
- **Top-Down Search**: Start with the goal (the desired output) and work backward, decomposing the problem into subproblems that must be solved.

Enumerative search faces the fundamental challenge of combinatorial explosion. The space of possible programs grows rapidly with program size, making naive enumeration impractical for all but the simplest tasks. However, clever pruning, type-directed search, and domain-specific heuristics can make enumeration surprisingly effective.

## Version Space Algebras

Version spaces provide a more structured way to represent the set of all programs consistent with the given examples. Rather than generating programs one by one, version space algebras maintain a compact representation of all consistent hypotheses.

- **Version Space**: The subset of the hypothesis space (all possible programs) that is consistent with the training examples
- **Algebras**: Operations like union, intersection, and join that allow composing version spaces
- **Incremental Updates**: As more examples arrive, the version space shrinks, focusing search on increasingly plausible candidates

This technique is particularly powerful for domains with compositional structure, where complex programs are built from simpler components. Version space algebras can efficiently represent large sets of consistent programs without explicitly enumerating them.

## Stochastic and Evolutionary Search

When systematic search becomes intractable, stochastic methods offer an alternative. These approaches use randomness and population-based search to explore the program space.

- **Genetic Programming**: Evolve a population of programs through mutation, crossover, and selection based on fitness
- **Stochastic Local Search**: Randomly explore the neighborhood of candidate programs, accepting improvements and sometimes accepting worse solutions to escape local optima
- **Metropolis-Hastings and MCMC**: Sample programs from a probability distribution over the program space

Stochastic methods trade guarantees of completeness for the ability to explore vast program spaces. They often find acceptable solutions faster than exhaustive methods, though they may miss the "best" program.

---

PBE has driven many practical successes in program synthesis, from Flash Fill in Excel to data wrangling tools. The next chapter explores complementary deductive approaches that leverage formal specifications and constraint solving.
