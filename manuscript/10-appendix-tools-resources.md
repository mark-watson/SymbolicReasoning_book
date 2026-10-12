# Appendix: Essential Tools & Resources

The systems in this book are intentionally small: each fits on a page. The tools and papers below are their full-size relatives. Where a chapter example has a direct industrial or research counterpart, the pointer appears with that example's name. Check the project pages for current URLs when you go looking; links were verified against the projects' canonical homes at the time of writing.

## SMT and SAT Solvers

The constraint-based synthesis of Chapter 4 enumerates `{0 1 2 3}` by hand. Real synthesizers hand the same problem to a solver.

- **Z3** (Microsoft Research): the most widely used SMT solver, with APIs for Python, C++, and more. The `02-smt-constraints.rkt` template search is, in Z3, a few asserted equations over integer variables. <https://github.com/Z3Prover/z3>
- **CVC5**: the other major SMT solver, and the engine behind many SyGuS competition winners. Its native input language is the same SMT-LIB format the SyGuS benchmarks use. <https://cvc5.github.io>
- **MiniSat / CaDiCaL**: fast SAT solvers; useful when the synthesis problem bit-blasts to pure booleans.

## Synthesis Systems and Languages

- **Sketch** (Solar-Lezama): the sketching language demonstrated in miniature by `04-sygus-sketch.rkt` part 2: you write the algorithmic skeleton with `??` holes, and its CEGIS backend fills them. <https://people.csail.mit.edu/asolar/>
- **Rosette** (Torlak & Bodik): a solver-aided host language embedded in Racket, so the jump from this book's examples is short: `rosette` gives you `??` holes, `synthesize`, `verify`, and `solve` over real SMT backends. If you liked Chapter 4, install Rosette next. <https://emina.github.io/rosette/>
- **SyGuS competition**: annual syntax-guided synthesis competition with public benchmarks and reference grammars; the natural benchmark suite for anything you build after Chapter 4. <https://sygus.org>

## Neurosymbolic Frameworks

Each framework below has a toy relative in Chapter 6.

- **LTN: Logic Tensor Networks** (`01-logic-tensor-network.rkt`): "Logic Tensor Networks" (Badreddine, d'Avila Garcez, Serafini, Spranger, 2021) and the LTNtorch library (PyTorch). <https://github.com/logictensornetworks/LTNtorch>
- **LNN: Logical Neural Networks** (`02-logical-neural-network.rkt`): IBM's implementation and the paper "Logical Neural Networks" (Riegel et al., 2020). <https://github.com/IBM/LNN>
- **NeurASP** (`03-neurasp.rkt`): "NeurASP: Embracing Neural Networks into Answer Set Programming" (Yang, Ishay, Lee, 2020). Uses clingo as the symbolic backend; the real system's objective — P(answer | perception): is the one the chapter example adds as its data term. <https://github.com/azreasoners/NeurASP>
- **∂ILP: Differentiable ILP** (`04-dilp.rkt`): "Differentiable Inductive Logic Programming" (Evans & Grefenstette, 2018). The softmax-over-rules trick in the toy is a two-clause shadow of the paper's clause-selection machinery.
- **Answer Set Programming**: the clingo solver family (Potassco). <https://potassco.org>

## Program Synthesis from Examples

- **Flash Fill** (Gulwani, Microsoft Excel): "Automating String Processing in Spreadsheets Using Input-Output Examples" (POPL 2011). The `04-flash-fill-demo.rkt` toy admits its limits; the paper's DSL with substring/propagation is what actually shipped in Excel.
- **PROSE / FlashMeta**: the industrial framework around Flash Fill-style PBE: version-space algebras with deductive pruning (Polozov & Gulwani, "FlashMeta: A Framework for Inductive Program Synthesis", OOPSLA 2015). Chapter 2's `02-version-space-algebras.rkt` is the seed idea, and Chapter 3's `05-flash-fill-vsa.rkt` builds the DAG construction and intersection in miniature.
- **DreamCoder** (Ellis et al., 2020): library learning by wake-sleep cycles of program synthesis and compression. Chapter 7's hand-added `macro-inc-then-double` is what DreamCoder's compression step invents automatically. <https://github.com/ellisk42/ec>

## Scientific Discovery

- **AI Feynman** (Udrescu & Tegmark, 2020): equation discovery combining neural fitting with symbolic search over physics-inspired grammars; `04-equation-discovery-kepler.rkt` is the same parse-and-parsimony loop at 1/1000th the scale.
- **Symbolic regression**: the `gplearn` (Python) and PySR (Julia-backed) packages do production evolutionary equation search.
- **FunSearch** (Romera-Paredes et al., "Mathematical discoveries from program search with large language models", *Nature*, 2023): an LLM proposes programs, an evaluator scores them, and evolution keeps the best; new cap set constructions and bin-packing heuristics. Code and discovered programs: <https://github.com/google-deepmind/funsearch>
- **AlphaEvolve** (Google DeepMind, 2025): the FunSearch loop scaled into a general coding agent; found a 48-multiplication algorithm for 4x4 complex matrices.
- **AlphaGeometry** (Trinh et al., "Solving olympiad geometry without human demonstrations", *Nature*, 2024): a language model proposes auxiliary constructions for a symbolic deduction engine. <https://github.com/google-deepmind/alphageometry>
- **AlphaProof** (Google DeepMind, IMO 2024; *Nature*, 2025): proofs written in Lean and checked by its kernel; silver-medal standard at IMO 2024 together with AlphaGeometry 2.

## Benchmarks and Evaluation

- **The Abstraction and Reasoning Corpus (ARC)** (Chollet, 2019): the grid benchmark behind Chapter 9's 1-D analogue, now called ARC-AGI-1, with 800 public tasks. The companion essay "On the Measure of Intelligence" is the best statement of why memorization-resistant benchmarks matter.
- **ARC-AGI-2** (2025) and **ARC-AGI-3** (2026): the harder static successor and the interactive, game-based third version. Tasks, leaderboards, and rules: <https://arcprize.org>
- **ARC Prize technical reports**: "ARC Prize 2024: Technical Report" (arXiv:2412.04604) and "ARC Prize 2025: Technical Report" (arXiv:2601.10904) summarize which methods worked each year, with scores. The best single source for how synthesis, test-time training, and LLM approaches compare on ARC.
- **SCAN** (Lake & Baroni, 2018): the compositional generalization splits for instruction-following that `03-compositional-benchmark.rkt` shrinks to a 1-D grammar.

## Key Surveys and Books

- **Program Synthesis** (Gulwani, Polozov, Singh, 2017): the standard tutorial survey, organized by the same inductive/deductive axis as Chapters 3-4.
- **Deductive Program Synthesis** (Manna & Waldinger, classic): where the proof-extraction view of Chapter 4 comes from.
- **Neurosymbolic AI: The 3rd Wave** (d'Avila Garcez & Lamb, 2020): the paradigm survey behind Chapters 5-6.

## A Suggested Path

If the book worked for you, a natural follow-up sequence is: install Rosette and redo Chapter 4's examples with a real solver; port Chapter 6's LTN to LTNtorch to see analytic gradients replace finite differences; then try one Kaggle ARC task with the version-space and parsimony tools of Chapters 2 and 8. Each step is the corresponding chapter with the training wheels off.
