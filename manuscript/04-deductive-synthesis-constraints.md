# Deductive Synthesis & Constraint-Based Methods

The previous chapter showed how programs can be induced from input-output examples alone. That approach is powerful, but inductive systems generalize from data without ever proving that the result is correct. Deductive synthesis takes the opposite stance: a program is *derived* from a formal specification in such a way that correctness is established by construction. Where inductive synthesis asks "which program fits these examples?", deductive synthesis asks "which program follows logically from this specification?"

In this chapter we explore four complementary techniques: synthesis from constructive proofs, constraint solving with SAT and SMT solvers, Counter-Example Guided Inductive Synthesis (CEGIS), and syntax-guided synthesis with grammars and sketches. Together these methods form the backbone of modern correct-by-construction program synthesis, used in systems such as Sketch, Rosette, and the SyGuS competition solvers.

All code examples for this chapter are in `source-code/04-deductive-synthesis-constraints/`. The examples are written in plain Racket and deliberately implement small versions of the algorithms by hand, so the search and verification logic is visible rather than hidden inside an external solver.

## Programs from Proofs: Deductive Synthesis

The oldest idea in program synthesis is also the most elegant: proving a theorem and extracting a program as a byproduct. The Curry-Howard correspondence tells us that propositions are types and proofs are programs. If we state the specification "for inputs x and y there exists an output z such that z = x + y" and prove it constructively, the proof must exhibit a witness for z, and that witness is the program.

The example `01-proof-based-synthesis.rkt` implements a tiny sequent-style derivation engine. A specification is a term in a small logic, and `derive` searches for a proof while simultaneously building the corresponding program term:

```racket
(define (derive prop env)
  (match prop
    [(? symbol? s)
     (if (memq s env)
         (cons (list 'axiom s) s)
         #f)]
    [`(and ,p ,q)
     (let ((a (derive p env))
           (b (derive q env)))
       (if (and a b)
           (cons (list 'and-intro (car a) (car b))
                 (list 'cons (cdr a) (cdr b)))
           #f))]
    [`(ex ,v (= ,v2 (+ ,x ,y)))
     #:when (and (eq? v v2) (memq x env) (memq y env))
     (cons (list 'exists-intro v (list '+ x y))
           (list '+ x y))]
    [`(=> ,p ,q)
     (let ((r (derive q (cons p env))))
       (if r
           (cons (list 'imp-intro p (car r))
                 (list 'lambda (list p) (cdr r)))
           #f))]
    [_ #f]))
```

Each rule of the logic has a computational interpretation. Proving a conjunction builds a pair. Proving an implication by assuming the premise and deriving the conclusion yields a lambda expression, since the resulting program maps the assumed input to the derived output. Proving an existential with an equality body yields the witness computation itself.

Running the file shows both the proof and the extracted program growing in lockstep:

```
Spec:   (=> x (=> y (ex z (= z (+ x y)))))
Assume: ()
Proof:  (imp-intro x (imp-intro y (exists-intro z (+ x y))))
Program: (lambda (x) (lambda (y) (+ x y)))
```

The proof term records every inference step, which makes the derivation auditable. The final case in the file, asking for a witness of `(= z (+ x w))` when only x and y are in scope, fails gracefully: there is no derivation, so there is no program. That failure is informative, because it says exactly which assumption is missing, something an example-driven system cannot tell you.

## Constraint Solving: SAT and SMT

Deductive proof search is elegant but often intractable for realistic programs. A pragmatic middle ground is to encode the synthesis problem as a set of constraints over unknown program components and hand those constraints to a SAT or SMT solver. This is the approach of systems like Sketch and Rosette: the programmer writes a parameterized template, and the solver searches the space of hole fillings for one that satisfies the specification.

The example `02-smt-constraints.rkt` demonstrates the pattern with a simple arithmetic template. We seek constants a and b such that `f(x) = a*x + b` agrees with three input-output examples:

```racket
(define domain '(0 1 2 3))
(define examples '((0 . 1) (1 . 3) (2 . 5)))

(define (f a b x) (+ (* a x) b))

(define (satisfies-all? a b)
  (andmap (lambda (ex)
            (= (f a b (car ex)) (cdr ex)))
          examples))

(define (solve-constraints)
  (for*/first ((a domain)
               (b domain)
               #:when (satisfies-all? a b))
    (list a b)))
```

The loop in `solve-constraints` plays the role of the solver's decision procedure. A real SMT solver does exactly this conceptually, but with powerful pruning: it encodes holes as variables, the template as arithmetic constraints, and the examples as assertions, then applies combining decision procedures for the relevant theories (integers, bit vectors, arrays, uninterpreted functions).

The output shows unsuccessful candidates failing with UNSAT before the satisfying assignment is found:

```
  Try a=2 b=0: f(0)=0 f(1)=2 f(2)=4   UNSAT

Solution found: a = 2, b = 1
Synthesized program: f(x) = 2*x + 1
Verification against examples:
  f(0) = 1 (expected 1) OK
  f(1) = 3 (expected 3) OK
  f(2) = 5 (expected 5) OK
```

The important property of constraint-based synthesis is that the solver's answer is definitive for the chosen template and domain. If the solver reports UNSAT, no filling of the holes within the given domains can work, which is a much stronger statement than "we did not find a program yet."

## Counter-Example Guided Inductive Synthesis

Constraint solving over templates works beautifully when the template is right, but what if we do not know the program shape in advance? CEGIS, introduced by Solar-Lezama and colleagues, resolves this by splitting synthesis into a dialogue between two components:

1. A **synthesizer** proposes a candidate program that is correct on the examples seen so far.
2. A **verifier** checks the candidate against the full specification. If it fails, the verifier returns a counter-example input, which is added to the example set, and the loop repeats.

The verifier never enumerates programs, and the synthesizer never checks the full specification. Each side does what it is good at.

The example `03-cegis.rkt` synthesizes a program for the hidden specification `f(x) = 2*x` over x in 0..5, using a grammar of arithmetic expressions. The verifier compares the candidate against the specification and returns the first falsifying input:

```racket
(define (verify candidate)
  (define (spec x) (* 2 x))
  (for/first ((x '(0 1 2 3 4 5))
              #:when (not (= (eval-expr candidate x) (spec x))))
    x))
```

The CEGIS loop threads the growing example set through rounds of synthesis and verification:

```racket
(let ((cex (verify candidate)))
  (cond
    [(not cex)
     (displayln "Verifier: no counter-example found. CORRECT.")
     candidate]
    [else
     (displayln (format "Verifier: counter-example input x = ~a" cex))
     (loop (append examples (list (cons cex (* 2 cex))))
           (+ round 1))]))
```

Running the example shows the signature behavior of CEGIS:

```
--- Round 1 ---
Examples so far: ((0 . 0))
Candidate: x
Verifier: counter-example input x = 1
--- Round 2 ---
Examples so far: ((0 . 0) (1 . 2))
Candidate: (+ x x)
Verifier: no counter-example found. CORRECT.

Final synthesized program: (+ x x)
Check: (0 2 4 6 8 10)
```

Notice the economy of the process. The first candidate, the identity function, is consistent with the seed example 0 maps to 0 but is wrong in general; the verifier catches this with x = 1. After only two examples the synthesizer produces `(+ x x)`, which the verifier confirms is correct on every input. Pure PBE would have needed many more examples, chosen carefully, to rule out all the wrong candidates that CEGIS eliminates with a single targeted counter-example each round.

## Syntax-Guided Synthesis and Sketches

CEGIS still searches a large program space. SyGuS, standardized in an annual competition, narrows that space by requiring the user to supply a grammar: a context-free description of every program the synthesizer is allowed to consider. Search then proceeds only over grammar-conformant expressions.

The example `04-sygus-sketch.rkt` defines a small integer-expression grammar with conditionals and enumerates it by depth:

```racket
(define (gen-int depth)
  (if (= depth 0)
      '(x y 0 1)
      (append
       '(x y 0 1)
       (for*/list ((a (gen-int (- depth 1)))
                   (b (gen-int (- depth 1))))
         `(+ ,a ,b))
       (for*/list ((a (gen-int (- depth 1)))
                   (b (gen-int (- depth 1))))
         `(- ,a ,b))
       (for*/list ((c (gen-bool 0))
                   (t (gen-int (- depth 1)))
                   (e (gen-int (- depth 1))))
         `(ite ,c ,t ,e)))))
```

With this grammar and four examples, the synthesizer finds a program equivalent to the max function:

```
Part 1: synthesize max2 from examples (depth-2 enumeration)
  Synthesized: (+ 0 (ite (<= x y) y x))
```

The answer is syntactically clumsy, with a redundant `(+ 0 ...)`, but it is exactly what depth-limited grammar enumeration produces: the first well-formed program that satisfies the examples. Real SyGuS solvers add aggressive simplification and equivalence reduction to avoid such noise.

The second half of the file demonstrates sketch completion, a close relative of SyGuS in which the human writes the algorithmic skeleton and the synthesizer fills in holes. Given the template `(ite (<= x y) ?? ??)` and hole domain `{x y 0 1}`, enumeration over hole fillings instantly yields the classic max program:

```
Part 2: sketch completion
  Template: (ite (<= x y) ?? ??), holes from {x y 0 1}
  Completed sketch: (ite (<= x y) y x)
```

Sketches and grammars encode expert knowledge about program structure. The more structure the user supplies, the smaller the search space and the stronger the guarantees about the shape of the result.

## Running the Examples

All four demonstrations run with a stock Racket installation and no external packages. Each is self-contained and prints a narrated trace of its search:

```bash
cd source-code/04-deductive-synthesis-constraints
racket 01-proof-based-synthesis.rkt   # Programs extracted from proofs
racket 02-smt-constraints.rkt         # Constraint solving over a template
racket 03-cegis.rkt                   # Counter-example guided loop
racket 04-sygus-sketch.rkt            # Grammar enumeration and sketches
```

The traces are worth reading carefully. In `01-proof-based-synthesis.rkt`, watch how the proof term and program term grow together. In `03-cegis.rkt`, count how few examples were needed to pin down the correct program. These traces are the chapter's theory made visible.

## Interpreting the Results

Each technique occupies a different point in the trade-off between automation, expressiveness, and guarantees:

- **Proof-based synthesis** gives the strongest correctness story, because the program is literally the computational content of a proof, but proof search scales poorly beyond small theories.
- **Constraint solving** trades proof structure for raw search power. It is definitive within its template and domains, and reports UNSAT when no solution exists, but it cannot invent program shapes the template does not allow.
- **CEGIS** recovers flexibility by using a verifier as an adversarial example generator, combining the strengths of a synthesizer that never sees the full spec and a verifier that never searches programs.
- **SyGuS and sketches** inject human knowledge as a grammar or template, shrinking the search space by orders of magnitude at the cost of requiring the user to know roughly what the solution looks like.

In practice, industrial systems combine these ideas: Sketch uses CEGIS over user-supplied sketches, and most competitive SyGuS solvers are essentially optimized constraint solvers with grammar-aware pruning.

## Wrap Up

Deductive and constraint-based synthesis complement the inductive methods of the previous chapter. Where inductive synthesis bets on generalization from data, the methods here bet on logic: specifications, constraints, and grammars that rule out wrong programs by construction. The four examples in this chapter, though small, each contain the seed of a real toolchain. Proof extraction lives on in proof assistants such as Coq, constraint solving in Rosette, CEGIS in Sketch and its descendants, and syntax-guided search in the SyGuS ecosystem. As specifications grow more complex, the limiting factor becomes search tractability, which is exactly where the neural methods of the next chapter enter the story.

## Optional Practice Problems

1. Extend the derivation engine in `01-proof-based-synthesis.rkt` with a rule for disjunction: to prove `(or p q)`, try proving `p`, and if that fails prove `q`. What program term should the extracted program be, and how does its behavior relate to a conditional?

2. Modify `02-smt-constraints.rkt` so the template is quadratic: `f(x) = a*x*x + b*x + c` with all holes in `(0 1 2 3)`. Find examples that make the linear template UNSAT but the quadratic template satisfiable.

3. The verifier in `03-cegis.rkt` returns only the first counter-example it finds. Change it to return *all* falsifying inputs and add every one to the example set. Does CEGIS converge in fewer rounds, or does the extra information not help for this specification?

4. In `03-cegis.rkt`, replace the specification `2*x` with `x*x + x` and find the minimum grammar depth at which the synthesizer can succeed. What does this tell you about the relationship between program complexity and search cost?

5. Sketch a grammar in `04-sygus-sketch.rkt` for the absolute-value function `|x|` and synthesize it from examples `(-3 . 3)`, `(0 . 0)`, `(4 . 4)`. Then write the same solution as a two-hole sketch and compare the search spaces.

6. Add a third part to `04-sygus-sketch.rkt` that detects ambiguity: find two *different* programs in the grammar that both satisfy all four max2 examples. What does ambiguity in the example set imply about the guarantees that synthesis from examples can provide?
