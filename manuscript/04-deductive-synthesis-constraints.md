# Chapter 4: Deductive Synthesis & Constraint-Based Methods

The previous chapter showed how programs can be induced from input-output examples alone. That approach is powerful, but inductive systems generalize from data without ever proving that the result is correct. Deductive synthesis takes the opposite stance: a program is *derived* from a formal specification in such a way that correctness is established by construction. Where inductive synthesis asks "which program fits these examples?", deductive synthesis asks "which program follows logically from this specification?"

In this chapter we explore four complementary techniques: synthesis from constructive proofs, constraint solving with SAT and SMT solvers, Counter-Example Guided Inductive Synthesis (CEGIS), and syntax-guided synthesis with grammars and sketches. Together these methods form the backbone of modern correct-by-construction program synthesis, used in systems such as Sketch, Rosette, and the SyGuS competition solvers.

All code examples are in `source-code/04-deductive-synthesis-constraints/`. They are written in plain Racket so search and verification are visible. Each file uses an explicit `provide` (e.g., `derive`, `solve-constraints`, `cegis`, `gen-int`), `racket/match`, and `(module+ main ...)`/`(module+ test ...)` so `require` is silent. A note on evaluators: you will see `eval-expr` and `eval-dsl` defined locally in each file rather than imported from `utils/eval.rkt`. That is deliberate — the grammars here differ from the shared one (CEGIS has `x` but no `-`; the SyGuS file adds `ite` and `<=` and evaluates against two variables), and Chapter 1's utils section explains the pattern: utils holds the common core, chapter files hold the grammar-specific extension. String helpers are imported from `utils/string.rkt` where needed, and the `02-smt`/`03-cegis`/`04-sygus` traces note that ordering by size gives the smallest fitting program.

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

![The CEGIS loop on the hidden specification f(x) = 2x](images/ch4-cegis-loop.png)

The example `03-cegis.rkt` synthesizes a program for the hidden specification `f(x) = 2*x` over x in 0..5, using a grammar of arithmetic expressions. The synthesizer enumerates programs up to depth 2 and sorts them by node count, so it always proposes the smallest program that fits:

```racket
(define (gen-exprs depth)
  (define (layer depth)
    (if (= depth 0)
        '(x 0 1)
        (let ([subs (layer (- depth 1))])
          (append '(x 0 1)
                  (for*/list ([a subs] [b subs]) `(+ ,a ,b))
                  (for*/list ([a subs] [b subs]) `(* ,a ,b))))))
  (sort (layer depth) < #:key ast-size #:cache-keys? #t))
```

The sort matters. Without it, every `+` program comes before every `*` program, and for examples of `x^2` the synthesizer returns `(+ 0 (* x x))` rather than `(* x x)`. Racket's `sort` is stable, so programs of equal size keep their generation order.

The verifier compares the candidate against the specification and returns the first falsifying input. The specification and the inputs it checks are arguments, so the same loop can chase any target function:

```racket
(define default-spec (lambda (x) (* 2 x)))
(define default-domain '(0 1 2 3 4 5))

(define (verify candidate [spec default-spec] [domain default-domain])
  (for/first ([x domain] #:unless (= (eval-expr candidate x) (spec x)))
    x))
```

Checking six inputs is bounded verification. A real verifier would prove the property for every `x`.

The CEGIS loop threads the growing example set through rounds of synthesis and verification, and stops after `max-rounds` rounds:

```racket
(define (cegis max-rounds
               #:spec [spec default-spec]
               #:domain [domain default-domain]
               #:seed [seed (list (cons (first domain) (spec (first domain))))]
               #:trace? [trace? #f])
  (let loop ([examples seed] [round 1])
    (cond
      [(> round max-rounds) (when trace? (displayln "Round limit reached.")) #f]
      [else
       (define candidate (synthesize examples 2))
       (define cex (and candidate (verify candidate spec domain)))
       (cond
         [(not candidate) #f]
         [(not cex) candidate]
         [else (loop (append examples (list (cons cex (spec cex)))) (+ round 1))])])))
```

The listing omits the trace output; the file prints each round when called with `#:trace? #t`.

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

Change the specification to `x^2` with `(cegis 10 #:spec (lambda (x) (* x x)))` and the loop needs three rounds. The candidates go `x`, then `(+ x x)`, which fits the counter-example `(2 . 4)` by coincidence, then `(* x x)`.

The same loop runs inside today's LLM coding agents. An agent asked to fix a bug writes a patch (the candidate), runs the test suite (the verifier), reads the failing test's output (the counter-example), and writes a new patch with that failure in its prompt. The synthesizer is a language model rather than an enumerator, and the verifier is a test suite rather than a proof, so neither side gives the guarantees of this chapter. The shape is the same, though, and so is the lesson: a cheap, reliable check that returns a specific failure is worth more than a smarter generator. Chapter 5 returns to this idea with a learned proposer in the synthesizer's seat.

## Syntax-Guided Synthesis and Sketches

CEGIS still searches a large program space. SyGuS, standardized in an annual competition, narrows that space by requiring the user to supply a grammar: a context-free description of every program the synthesizer is allowed to consider. Search then proceeds only over grammar-conformant expressions.

The example `04-sygus-sketch.rkt` defines a small integer-expression grammar with conditionals and enumerates it by depth. Guards stay shallow: boolean conditions compare depth-0 integer expressions only, so `gen-bool` takes no depth argument. The generator builds the program list in layers. Every depth-`d` program comes before any program of depth `d+1`, and each new layer holds only the programs with at least one child from the layer just below, so no program appears twice:

```racket
(define int-leaves '(x y 0 1))

(define (gen-bool)
  (for*/list ([a int-leaves] [b int-leaves]) `(<= ,a ,b)))

(define (gen-int depth)
  (let loop ([d 0] [all int-leaves] [newest int-leaves])
    (if (= d depth)
        all
        (let* ([new? (lambda (e) (member e newest))]
               [pairs (for*/list ([a all] [b all] #:when (or (new? a) (new? b)))
                        (cons a b))]
               [layer (append
                       (for/list ([p pairs]) `(+ ,(car p) ,(cdr p)))
                       (for/list ([p pairs]) `(- ,(car p) ,(cdr p)))
                       (for*/list ([c (gen-bool)] [p pairs]) `(ite ,c ,(car p) ,(cdr p))))])
          (loop (+ d 1) (append all layer) layer)))))
```

With this grammar and four examples, the synthesizer finds the max function:

```
Part 1: synthesize max2 from examples (depth-2 enumeration)
  Synthesized: (ite (<= x y) y x)
```

Layering is what keeps the answer clean. A generator that rebuilds the full list at each depth puts `(+ 0 (ite (<= x y) y x))` ahead of the depth-1 `ite`, and returns the padded form. Shallowest-first order is a cheap stand-in for the simplification and equivalence reduction that real SyGuS solvers perform.

The second half of the file demonstrates sketch completion, a close relative of SyGuS in which the human writes the algorithmic skeleton and the synthesizer fills in holes. Given the template `(ite (<= x y) ?? ??)` and hole domain `{x y 0 1}`, enumeration over hole fillings instantly yields the classic max program:

```
Part 2: sketch completion
  Template: (ite (<= x y) ?? ??), holes from {x y 0 1}
  Completed sketch: (ite (<= x y) y x)
```

Sketches and grammars encode expert knowledge about program structure. The more structure the user supplies, the smaller the search space and the stronger the guarantees about the shape of the result.

## Running the Examples

All four are explicit-`provide` modules with `(module+ main ...)` for traces and `(module+ test ...)` for checks, so `require` is silent and `raco test .` runs without demo output:

```bash
cd source-code/04-deductive-synthesis-constraints
racket 01-proof-based-synthesis.rkt   # programs from proofs
racket 02-smt-constraints.rkt
racket 03-cegis.rkt
racket 04-sygus-sketch.rkt
raco test .                           # 27 checks, no demo output
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
