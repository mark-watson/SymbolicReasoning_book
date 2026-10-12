# Chapter 8: Program Synthesis for Scientific Discovery

Science advances through hypothesizing, testing, and refinement. Program synthesis automates each step: hypotheses are programs, tests check them against data, refinement re-searches where they fail. The code is in `source-code/08-program-synthesis-scientific-discovery/` and runs with stock Racket. Each file now has an explicit `provide`, uses `racket/match`, and keeps demos in `(module+ main ...)` with `raco test` checks; `clamp01` and `size` are shared from `utils/`.

## Automated Hypothesis Generation and Testing

A scientific hypothesis is a small, executable explanation for observed data. Rather than treating it as a number (a fit coefficient) or a black-box prediction rule, we write it as a program: `V = (* i 2)` says "the voltage is the current multiplied by resistance 2." A hypothesis in this form is compact, interpretable, and falsifiable: give it any current you like and it predicts a voltage.

The example `01-hypothesis-generation.rkt` builds a tiny hypothesis generator for a resistor circuit. It enumerates candidate formulas over a grammar with constants, the measured variable `i`, and the operators `+`, `-`, `*`, `/`, and `sq`:

```racket
(define (gen-hypotheses depth)
  (define leaves '(i 1 2 3 4))
  (if (= depth 1)
      leaves
      (let ((smaller (gen-hypotheses (- depth 1))))
        (dedupe
         (append
          leaves
          (for/list ((a smaller)) `(sq ,a))
          (for*/list ((a leaves) (b leaves)) `(* ,a ,b))
          (for*/list ((a smaller) (b leaves)) `(* ,a ,b))
          (for*/list ((a smaller) (b leaves)) `(+ ,a ,b))
          (for*/list ((a smaller) (b leaves)) `(/ ,a ,b)))))))
```

Each hypothesis is scored by two components: the *fit error* (sum of squared prediction errors on the measurements) and a *simplicity penalty* (the AST size). The combined score is what scientists call an Occam prior: prefer the simplest hypothesis that fits the data.

```racket
(define (score e data (lambda-simple 0.5))
  (+ (fit-error e data) (* lambda-simple (size e))))
```

For simulated measurements of `V = 2 I` with small noise, the search returns exactly the right form at the top of the ranked list:

```
Top 5 hypotheses by fit + simplicity:
  (* i 2)   score=1.5223  size=3
  (* 2 i)   score=1.5223  size=3
  (+ i i)   score=1.5223  size=3
  (+ i 3)   score=11.422300000000003  size=3
  (+ 3 i)   score=11.422300000000003  size=3

Selected hypothesis: V = (* i 2)
```

Three hypotheses tie at the optimum because all three are the same law expressed three different ways. This is a feature of parsimony-first ranking, not a bug: when two hypotheses have equal fit, we rank the simpler one higher, and ties are surfaced as ties, which tells the experimenter there are equivalent formulations to test with a new experiment.

This loop—generate, score by fit + simplicity, report the top hypotheses—is a template for automated scientific discovery. Real systems do exactly this on richer grammars (trigonometric functions, differential operators, symmetries) and on much larger datasets, but the underlying search-and-parsimony logic is identical.

## Data-Efficient Learning for Scientific Domains

Scientific data is expensive. A particle physicist has a handful of collision events; an ecologist may have years of sparse sensor readings; a chemist may have one or two measurements per molecule. Machine learning systems trained on millions of examples are simply not available. Program synthesis offers a different lever: by strongly constraining the hypothesis space with a grammar of physically plausible formulas, it is possible to recover the correct law from a handful of noisy observations.

The example `02-data-efficient-learning.rkt` simulates a free-fall experiment with just four measurements at t = 1, 2, 3, 4 seconds:

```racket
(define measurements
  '((1 . 4.95) (2 . 19.6) (3 . 44.0) (4 . 78.5)))
```

These four points are noisy samples of `d = (1/2) g t^2` with `g ≈ 9.8 m/s^2`, so we'd like the system to find `(* (sq t) 5)` (a constant close to `g/2 = 4.9`). The enumerator walks a grammar of arithmetic expressions over `t` and produces a few thousand candidates:

```racket
(define (gen-exprs depth)
  (if (= depth 1)
      leaves
      (let ((smaller (gen-exprs (- depth 1))))
        (append
         leaves
         (for/list ((a smaller)) `(sq ,a))
         (for*/list ((a smaller) (b leaves)) `(* ,a ,b))
         (for*/list ((a smaller) (b leaves)) `(+ ,a ,b))
         (for*/list ((a smaller) (b leaves)) `(/ ,a ,b))))))
```

The system then ranks candidates by fit error on the four points. The result is unambiguous:

```
Top 5 by fit (with size):
  (* (sq t) 5)  err=3.4124999999999988 size=4
  (* (* t t) 5)  err=3.4124999999999988 size=5
  (* (* t 5) t)  err=3.4124999999999988 size=5
  (* (* 5 t) t)  err=3.4124999999999988 size=5
  (sq (* t 2))  err=288.1125 size=4
```

Three of the top four hypotheses are trivially equivalent re-writings of `5 * t^2`. The fifth is a different functional form, `4 t^2`, and it is decisively worse. Because the grammar encodes a plausible family of laws, four data points suffice to pin down the right family unambiguously; a purely statistical regressor would have needed many more examples and would still be interpolating within its training range rather than extrapolating the law `d ∝ t²`.

This is the data-efficiency advantage of synthesis in scientific domains: strong priors embodied in the grammar turn a handful of points into a confident, interpretable conclusion.

## Causal and Temporal Reasoning in Synthesis

Correlation is not causation. A model that merely fits a curve to past observations will happily predict a hospitalization drop when vaccination rises, but it cannot answer "what hospital level would we see if we doubled vaccination?" or "what if infections were eliminated by a new drug?" Those are *counterfactual* questions, and answering them requires a model that encodes structural (mechanistic) relationships, not just statistical ones.

The example `03-causal-reasoning.rkt` builds a tiny causal model with three variables—`vaccinate`, `infection`, and `hospital`—and two directed causal links:

```racket
(define links
  (list (list 'vaccinate 'infection -0.7)   ; vaccinate lowers infection
        (list 'infection 'hospital   0.8))) ; infection raises hospital
```

Each node also has a baseline value; the links specify how parent's value shifts the child's. The core operation is *propagation*: starting from the observed baselines (or from an intervention), compute each node's value in topological order, clamped to [0,1]:

```racket
(define (link-strength from to)
  (for/first ([l links] #:when (and (eq? (first l) from) (eq? (second l) to))) (third l)))

(define (propagate interventions)
  (define vaccinate (hash-ref interventions 'vaccinate (hash-ref baseline 'vaccinate)))
  (define infection
    (if (hash-has-key? interventions 'infection) (hash-ref interventions 'infection)
        (clamp01 (+ (hash-ref baseline 'infection) (* (or (link-strength 'vaccinate 'infection) -0.7) vaccinate)))))
  (define hospital
    (if (hash-has-key? interventions 'hospital) (hash-ref interventions 'hospital)
        (clamp01 (+ (hash-ref baseline 'hospital) (* (or (link-strength 'infection 'hospital) 0.8) infection)))))
  (hash 'vaccinate vaccinate 'infection infection 'hospital hospital))
;; links is now read via link-strength, not hard-coded
```

The three scenarios in the example are:

- **Observational:** run the model without interventions.
- **do(vaccinate = 0.8):** force vaccination to double and propagate the consequences.
- **do(infection = 0):** force infection to zero (an extreme intervention) and look at hospitalization.

Running the example shows the difference between prediction and intervention:

```
Observational:     vaccinate=0.4 infection=0.32 hospital=0.756
do(vaccinate=0.8): vaccinate=0.8 infection=0.04  hospital=0.532
do(infection=0):                 infection=0.0   hospital=0.5
```

Notice that the *observational* hospital value (`0.756`) is computed endogenously from the observed vaccination level, not fed in by hand; and that *do(infection=0)* leaves `vaccinate` untouched while slashing `hospital` to its baseline of `0.5`. These are exactly the kinds of answers a purely correlational model cannot give. A synthesis system that can produce causal models like this—rather than just fitted curves—gives scientists the ability to ask "what if" and to design experiments that discriminate between competing causal structures.

## Case Study: Equation Discovery — Kepler's Third Law

We close with a concrete case study of program synthesis as scientific discovery. Kepler's third law states that the square of a planet's orbital period is proportional to the cube of the semi-major axis of its orbit: `T^2 = k a^3`. Suppose a modern astronomer has a handful of (semi-major axis, period-squared) measurements and no memory of Kepler. Can a synthesis system recover the law?

The example `04-equation-discovery-kepler.rkt` does exactly that. The grammar is restricted to power-law-style expressions: atoms are `a` and small integers, unary operators are `pow2` and `pow3`, and binary combinations are `*` and `+`:

```racket
(define (gen-laws)
  (define atoms '(a 1 2 3))
  (define unary (append (map (lambda (x) `(pow2 ,x)) atoms)
                        (map (lambda (x) `(pow3 ,x)) atoms)))
  (remove-duplicates
   (append atoms unary
           (for*/list ([x atoms] [y (append atoms unary)]) `(* ,x ,y))
           (for*/list ([x (list 'a)] [y unary]) `(* ,x ,y))
           (for*/list ([x atoms] [y unary]) `(+ ,x ,y)))
   equal?))
;; duplicate (* a (pow2 a)) now removed; fit-error is arity 1 and closes over observations
```

Six observations, with small noise, are provided for a in the range 1.0 to 3.5 (true law `T^2 = a^3`):

```racket
(define observations
  '((1.0 . 1.02) (1.5 . 3.40) (2.0 . 7.95)
    (2.5 . 15.70) (3.0 . 27.10) (3.5 . 42.80)))
```

Scoring combines fit and simplicity as before. The top-ranked candidate is exactly `(pow3 a)` with the lowest combined score, and the system then *verifies* the law on two held-out points (a = 4.0 and a = 4.5):

```
Top candidates (law, fit error, size, score):
  T^2 = (pow3 a)         err=0.0248  size=2 score=0.2248
  T^2 = (* a (pow2 a))   err=0.0248  size=4 score=0.4248
  T^2 = (* 1 (pow3 a))   err=0.0248  size=4 score=0.4248
  ...

Discovered law: T^2 = (pow3 a)

Verification on held-out a values (4.0, 4.5):
  a=4.0 predicted T^2=64.0 actual 64.0
  a=4.5 predicted T^2=91.125 actual 91.125
```

The discovered law is short, exact to within the simulated noise, and it generalizes to inputs outside the training range. This is a template used by modern equation-discovery systems such as AI Feynman and its successors: enumerate formulas in a physically motivated grammar, score by fit + parsimony, and verify on held-out data. When the grammar happens to match the true functional family, the system recovers a law that looks indistinguishable from one a human scientist might write down.

## From Kepler to FunSearch: Synthesis at Research Scale

The Kepler example recovers a law people already knew. The question this chapter opened with is whether synthesis can find things nobody knew. Since 2023 several systems have answered yes, and all of them use the split of Chapter 5: a learned model proposes, and a strict checker decides.

- **FunSearch** (Romera-Paredes et al., *Nature*, December 2023) pairs a pretrained LLM with an automatic evaluator in an evolutionary loop. The LLM writes variations of the best programs found so far; the evaluator runs each one and scores it; the best survive into the next prompt. Applied to the cap set problem in extremal combinatorics, it found larger cap sets than the best previously known constructions. Applied to online bin packing, it found heuristics that beat widely used baselines. The detail that matters for this book: FunSearch searches for *programs that build solutions*, not for the solutions themselves. The output is short code a mathematician can read, which is the same argument this chapter makes for `(pow3 a)` over a fitted curve.
- **AlphaEvolve** (Google DeepMind, May 2025) scales the FunSearch loop into a general coding agent driven by Gemini models. Its best-known result is an algorithm that multiplies two 4x4 complex-valued matrices with 48 scalar multiplications, one fewer than the 49 that Strassen's 1969 method gives when applied recursively.
- **AlphaGeometry** (Trinh et al., *Nature*, January 2024) solves olympiad geometry with a language model and a symbolic deduction engine. The engine derives every fact it can; when it gets stuck, the language model proposes an auxiliary construction (a new point or line), and the engine tries again. The model was trained on about 100 million synthetic theorems and proofs, with no human demonstrations. On a benchmark of 30 olympiad geometry problems from 2000 to 2022 it solved 25 within competition time limits; the previous best method, Wu's method, solved 10.
- **AlphaProof** (Google DeepMind, July 2024; *Nature*, November 2025) writes proofs in the Lean proof assistant, whose kernel checks every step. With AlphaGeometry 2 handling the geometry problem, it scored 28 of 42 points at the 2024 International Mathematical Olympiad, the standard of a silver medal. Two caveats keep the result in proportion: humans first translated the problems into Lean, and the system used far more time than contestants get.

Each system has the three parts of the Kepler example at a larger scale. There is a grammar or language of candidates (Python functions, geometric constructions, Lean tactics). There is a generator that proposes candidates, now an LLM rather than an enumerator. And there is a checker that cannot be argued with: an evaluator that runs the code, a deduction engine, a proof kernel. The LLM supplies breadth and taste. The checker supplies the guarantee that makes the output count as knowledge. Take away the checker and you have a fluent model that is sometimes right; take away the generator and you have the Kepler example, exact but limited to spaces small enough to enumerate.

## Running the Examples

All four are explicit-`provide` modules with `(module+ main ...)`/`(module+ test ...)`; `require` is silent:

```bash
cd source-code/08-program-synthesis-scientific-discovery
racket 01-hypothesis-generation.rkt
racket 02-data-efficient-learning.rkt
racket 03-causal-reasoning.rkt
racket 04-equation-discovery-kepler.rkt
raco test .
```

Each prints a short trace of its search before the final answer, so you can see exactly which hypotheses were considered and why the winner won.

## Wrap Up

Scientific discovery is a good stress test for program synthesis: the data are noisy and scarce, the hypothesis space is large, and the answers must be interpretable enough for a domain expert to criticize or build on. The techniques in this chapter—parsimony-regularized search over a formal grammar, causal models with explicit interventions, and verification on held-out data—show how synthesis meets these constraints. The next part of the book turns to evaluation: how do we benchmark systems that claim to synthesize scientific knowledge, and how close are we to general-purpose synthesis-driven discovery?
