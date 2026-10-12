# Chapter 5: The Neurosymbolic Paradigm

*Part III — Neurosymbolic Program Synthesis.*

The previous chapter ended with a warning sign. Deductive synthesis gives beautiful guarantees, but constraint solving and theorem proving search exponentially large spaces. Purely inductive learning, by contrast, scales gracefully but learns statistical correlations without any built-in notion of correctness or compositionality. The neurosymbolic paradigm proposes to close this gap by combining the strengths of both approaches.

The core observation is simple: neural networks are remarkably good at *perception* and *pattern recognition*, while symbolic systems are remarkably good at *reasoning*, *composition*, and *verification*. A neurosymbolic system couples the two. The neural side translates raw, noisy input (pixels, text, sensor signals) into structured hypotheses. The symbolic side checks those hypotheses against logical constraints, composes them with known rules, and searches for executable programs that satisfy them. Both sides can inform each other during training, and—crucially—both sides are visible in the final artifact in a way that neither a hidden state nor a symbolic trace is alone.

All code examples for this chapter are in `source-code/05-neurosymbolic-paradigm/`. They are written in plain Racket and implement small versions of the neurosymbolic pipeline by hand, so the learning loop, the constraint checker, and the search procedure are all explicit. Shared math and logic helpers (`dot`, `hamming`, `t-and`, `t-impl`) are imported from `source-code/utils/math.rkt` and `utils/logic.rkt` so the five files do not redefine them. Each file is an explicit-`provide` module with `(module+ main ...)` for demos and `(module+ test ...)` for `raco test`.

```racket
(require "../utils/math.rkt")   ; dot, hamming
(require "../utils/logic.rkt")  ; t-and, t-impl
```

## Why Deep Learning Alone is Insufficient

Before building neurosymbolic systems it is worth pausing on the limits of end-to-end neural networks. Those limits fall into three broad categories: models interpolate but do not extrapolate, they memorize rather than compose, and they fail on problems whose solution requires explicit discrete reasoning.

The first example, `01-why-deep-learning-insufficient.rkt`, makes these abstract failure modes concrete with the simplest neural model possible: a perceptron trained with the perceptron update rule:

```racket
(define (perceptron xs ws)
  (if (> (dot xs ws) 0) 1 0))

(define (train-perceptron dataset weights0 epochs)
  (let loop ((ws weights0) (epochs epochs))
    (if (zero? epochs)
        ws
        (let loop2 ((ws ws) (data dataset))
          (if (null? data)
              (loop ws (- epochs 1))
              (let* ((item (car data))
                     (xs (cons 1 (car item)))
                     (y  (cadr item))
                     (pred (perceptron xs ws))
                     (err  (- y pred))
                     (ws*  (map (lambda (w x) (+ w (* err x))) ws xs)))
                (loop2 ws* (cdr data))))))))
```

The perceptron learns a weight vector `ws` whose dot product with the input (with a leading bias of `1`) crosses zero exactly on the training boundary. Each error triggers an additive update that shifts the hyperplane toward the misclassified point. Three experiments show the limits of this pattern.

First, the perceptron fits the OR-like dataset perfectly, reaching accuracy `1` after twenty passes. Second, the extrapolation experiment: the network is trained on all three *negative* points of an AND dataset — `(0 0)`, `(0 1)`, and `(1 0)`, each labeled `0` — and then asked for the held-out positive case `(1 1)`. The demo prints:

```
Train on (0,0),(0,1),(1,0) of AND, test on held-out (1,1)=1:
Learned weights: (0 0 0)
  Input (1 1) -> predict 0, true 1
Held-out prediction 0 vs true 1 -> FAIL (never saw a positive, cannot extrapolate)
```

Every training point was negative, so the perceptron rule never fired a single update and the weights stayed at zero. The model has no machinery for guessing that some unseen input pattern could be positive — it can only carve up what it has seen. (`dot` is imported from `utils/math.rkt`, and the file’s `accuracy` and `show-preds` are exported with an explicit `provide`.) Third, on XOR the perceptron plateaus at accuracy `1/2` no matter how many epochs it runs, because XOR is not linearly separable:

```
=== Part 3: XOR is not linearly separable ===
XOR accuracy after 50 epochs: 1/2
  Input (0 0) -> predict 1, true 0
  Input (0 1) -> predict 1, true 1
  Input (1 0) -> predict 0, true 1
  Input (1 1) -> predict 0, true 0
```

A deeper network would memorize XOR, but memorization is not the same as learning the parity rule. The model that memorizes XOR has no machinery for generalizing parity to longer bitstrings. What is missing is a symbolic layer that can state *what* the function is, not just approximate it on the training distribution.

## The Synergy of Neural Networks and Symbolic Search

The neurosymbolic response to these failures is to give each component of the system a clearly delimited job. Neural networks handle the messy, statistical work of perception; symbolic engines handle the sharp, logical work of composing what is perceived into verified programs.

The classic testbed for this division of labor is the digit-addition task. Given two images of handwritten digits, the system must output their sum. A purely neural model trained end-to-end on pairs of images and their sums tends to memorize the training pairs and fails on unseen digit combinations. A neurosymbolic pipeline, in contrast, trains a network to recognize individual digits and then *symbolically adds* the resulting integers.

The example `02-neural-symbolic-synergy.rkt` captures this architecture with a minimal stand-in for the perceptual network: a nearest-neighbor classifier over hand-coded 3x3 bitmaps. The `0` and `6` patterns are now distinct (the early draft duplicated them, making them indistinguishable), and `hamming` is imported from `utils/math.rkt`:

```racket
(define (recognize-digit pattern)
  (let ((best (argmin (lambda (pair) (hamming pattern (cdr pair)))
                      digit-alphabet)))
    (car best)))

(define (neurosymbolic-add pattern1 pattern2)
  (+ (recognize-digit pattern1)
     (recognize-digit pattern2)))
```

The symbolic layer is just `+`. The important part is where the seam lies: `recognize-digit` commits to a discrete digit label, and `+` then operates on that discrete object. If the perception layer is right about the two digits, the sum is correct by definition. Compare this with the pure neural baseline:

```racket
(define (pure-neural-baseline d1 d2)
  (let ((seen (assoc (cons d1 d2)
                     (map (lambda (p) (cons (cdr p) (car p)))
                          train-pairs))))
    (if seen (cdr seen) '?)))
```

The baseline is just a lookup table of `(d1 . d2) -> sum` pairs. When asked for `3 + 5`, which was never seen in training, it returns `'?`. The neurosymbolic pipeline answers `8`:

```
Trained 2+3 -> 5
Unseen 3+5 -> ?
Recognize 3 -> 3
Recognize 5 -> 5
3 + 5 -> 8
```

The lesson generalizes beyond toy digit arithmetic. In visual question answering, the perceptual network proposes scene graphs or object candidates and the symbolic layer runs compositional queries over them. In program synthesis, the neural side can rank a grammar's production rules by likelihood and the symbolic side still checks every candidate against the specification. Whenever there is a clearly stated formal constraint, symbolic execution protects the output from perceptual failure.

## Differentiable Reasoning and Logic

The architecture above keeps the two halves cleanly separated at inference time. A complementary idea is to keep them connected during *training* by making the symbolic layer differentiable. If logical connectives are smooth functions on [0,1], we can backpropagate through a logical formula and train its parameters with gradient descent. This is the foundation of Logic Tensor Networks and related systems.

The third example, `03-differentiable-reasoning.rkt`, builds a tiny differentiable reasoning engine from scratch. The building blocks are smooth *t-norms*—fuzzy relaxations of Boolean connectives:

```racket
(require "../utils/logic.rkt")  ; t-and, t-impl, t-not
;; product t-norm and Reichenbach implication are now shared
```

The product t-norm interprets conjunction as multiplication, so `and(x,y)` is high exactly when both conjuncts are high. The Reichenbach implication is a smooth relaxation of material implication: `1 - x + x*y` is `1` when `x` is `0` (vacuous truth), close to `1` when `x` and `y` are both high, and low when `x` is high and `y` is low.

With these primitives we can write a small logical knowledge base and a *satisfaction* score:

```racket
(define (satisfaction s)
  (let ((hs (hash-ref s 'human-socrates))
        (ms (hash-ref s 'mortal-socrates)))
    (t-and hs
           (t-impl hs ms))))
```

The KB asserts both that Socrates is human (a fact, in degree) and that humanity implies mortality (a rule, in degree). The satisfaction is their product conjunction. Because every operation is differentiable, we can compute how satisfaction changes if we increase our degree of belief in `mortal(socrates)`:

```racket
(define ((grad k h) s)
  (let ((s+ (hash-update s k (lambda (v) (min 1 (+ v h)))))
        (s- (hash-update s k (lambda (v) (max 0 (- v h))))))
    (/ (- (satisfaction s+) (satisfaction s-))
       (* 2 h))))
```

This is a finite-difference derivative. It perturbs the degree in one hash key by a small `h`, measures how the overall KB satisfaction changes, and divides by `2h` to get the gradient. A full Logic Tensor Network uses the same idea but with tensors of truth values instead of a scalar hash.

The training loop performs gradient ascent on the satisfaction score:

```racket
(define (learn steps lr)
  (let loop ((s (hash 'human-socrates 0.9
                      'mortal-socrates 0.2))
             (i 0))
    (if (= i steps)
        s
        (let* ((g      ((grad 'mortal-socrates 1e-4) s))
               (new-ms (max 0 (min 1 (+ (hash-ref s 'mortal-socrates)
                                        (* lr g))))))
          (loop (hash-set s 'mortal-socrates new-ms)
                (+ i 1))))))
```

Running the example shows the inference unfolding numerically:

```
=== Soft logic before training ===
human(socrates)  = 0.9  (given by perception)
mortal(socrates) = 0.2  (initial belief)
KB satisfaction  = 0.252
grad(sat, mortal(socrates)) = 0.81

=== After training (gradient ascent on satisfaction) ===
human(socrates)  = 0.9
mortal(socrates) = 1.0
KB satisfaction  = 0.9
```

The gradient at the start is `0.81`, which is exactly the derivative of the product `hs * (1 - hs + hs*ms)` with respect to `ms`, namely `hs^2 = 0.81`. Because the rule is satisfied only when `ms` is pulled upward, the gradient pushes `mortal(socrates)` toward `1.0`. The conclusion of the classical syllogism is not hand-coded; it is *learned* as the value that best satisfies the logical constraints.

This kind of differentiable reasoning is powerful for knowledge-base completion, question answering, and training perception networks subject to domain constraints. The neural side proposes soft beliefs; the symbolic side scores how well those beliefs obey logic; the gradient ties them together.

## Case Study: Compositional Reasoning

The final example, `04-compositional-reasoning-case-study.rkt`, confronts the neural and neurosymbolic approaches head-on in a single, one-shot synthesis task. Given one example, `3 -> 6`, the system must produce a function.

The pure neural baseline does what statistical models do when training data is extremely scarce: it memorizes the example and has no answer for anything else:

```racket
(define (pure-neural-synthesize examples)
  (displayln "Pure neural baseline: memorize nearest seen pair.")
  (list 'memorize examples))
```

The neurosymbolic synthesizer, in contrast, separates the problem into two stages. First it uses a tiny enumerative search (the symbolic engine) over a grammar of integer expressions, with an evaluator that *executes* every candidate:

```racket
(define (eval-expr e x)
  (match e
    ['x x]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]))

(define (enumerate examples depth)
  (findf (lambda (e) (satisfies? e examples))
         (gen-exprs depth)))
```

The synthesizer returns the first program that satisfies the example; because the grammar is finite and the evaluator is symbolic, the result is guaranteed to be correct on the evidence it has seen. In this run it returns `(+ x x)`:

```
=== Neurosymbolic synthesizer ===
Input example: ((3 . 6))
Synthesized program: (+ x x)
Check on unseen inputs: (0 2 4 6 8 10)
```

Notice the contrast in the two outputs. The neural baseline produces a memorized pair; the synthesizer produces an executable program. That program composes with the rest of the system: it can be inlined, optimized, analyzed by a type checker, or fed back into a new synthesis loop as a learned building block. Compositional generalization—making correct predictions about `(+ x x)` on inputs never seen—falls out automatically, because the artifact is symbolic rather than a table of nearest neighbors.

This case study is small, but the architecture scales. Real systems like NeurASP and DreamCoder do exactly this division of labor on larger problems: a neural model proposes, scores, and abstracts components, and a symbolic engine explores the space of compositions and verifies the results against constraints.

## Synthesis with Learned Proposers

The case study used a neural baseline only as a foil. The more useful pattern puts the learned model *inside* the search. A large language model (LLM) trained on code assigns a probability to every program it could write. Treat that model as a proposal distribution over the program space of Chapters 2 and 3, check each proposal with the evaluators and verifiers of Chapter 4, and you have the architecture behind most LLM-based program synthesis today. It needs no new machinery. The search engines stay; the order in which they try candidates changes.

The split of duties is strict. The proposer decides which candidates to try first. The verifier decides which candidates are right. A proposer can be biased, out of date, or simply wrong, and the system's answers stay correct, because nothing reaches the user without passing the verifier. A better proposer only makes the search cheaper.

![A learned proposer orders the candidates; a CEGIS verifier accepts or rejects them](images/ch5-learned-proposer.png)

### A probabilistic grammar as a stand-in for an LLM

`05-learned-proposer.rkt` shows the pattern at a scale you can read. The proposer is a probabilistic grammar trained on a corpus of twelve solved programs. It learns how often each symbol appears in each syntactic context: at the root, or as the left or right argument of `+`, `*`, or `-`. That is a bigram model over syntax trees, the smallest "language model of programs" that still picks up habits such as "the left argument of `*` is usually a constant."

```racket
(define (events e [ctx 'root])
  (match e
    [(list op a b) (append (list (cons ctx op))
                           (events a (cons op 0))
                           (events b (cons op 1)))]
    [s (list (cons ctx s))]))

(define (train-proposer corpus)
  (define counts (make-hash))
  (for* ([p corpus] [ev (events p)])
    (hash-update! counts ev add1 0))
  (for*/hash ([ctx (contexts)] [s symbols])
    (define total (for/sum ([t symbols]) (add1 (hash-ref counts (cons ctx t) 0))))
    (values (cons ctx s) (log (/ (add1 (hash-ref counts (cons ctx s) 0)) total)))))
```

Add-one smoothing keeps every production possible, so the proposer can still reach programs unlike anything in its corpus. The log probability of a program is the sum over its nodes, and `learned-order` sorts all 8,116 programs up to depth 2 by that score. The uniform baseline keeps the usual smallest-first order.

The search itself is the CEGIS loop of Chapter 4, with one change: it walks candidates in whatever order it is given.

```racket
(define (cegis-with-order order spec domain)
  (let loop ([examples (list (cons (first domain) (spec (first domain))))]
             [rounds 1]
             [tried 0])
    (define-values (cand n)
      (for/fold ([found #f] [n 0]) ([e order] #:break found)
        (values (and (fits? e examples) e) (add1 n))))
    (define cex
      (and cand
           (for/first ([x domain] #:unless (= (eval-expr-with-x cand x) (spec x))) x)))
    (cond [(not cand) (list #f rounds (+ tried n))]
          [(not cex) (list cand rounds (+ tried n))]
          [else (loop (append examples (list (cons cex (spec cex))))
                      (add1 rounds)
                      (+ tried n))])))
```

None of the four test tasks appears in the corpus. The run counts every candidate evaluation across all CEGIS rounds:

```
Search space: 8116 programs up to depth 2
Proposer trained on 12 solved programs

First five proposals, uniform: (x 1 2 3 (+ x x))
First five proposals, learned: (x 1 2 3 (* x x))

task        uniform tried             learned tried
2x + 3      16  (+ x (+ x 3))         59  (+ (* 2 x) 3)
3x - 1      292  (+ (+ x x) (- x 1))  59  (- (* 3 x) 1)
x^2 + 2     139  (+ 2 (* x x))        42  (+ (* x x) 2)
(x - 1)^2   6589  (* (- x 1) (- x 1)) 4324  (* (- x 1) (- x 1))
```

Three lessons are in this table.

First, the proposer pays off on tasks that look like its training data. `3x - 1` costs 292 candidates without the prior and 59 with it, and `x^2 + 2` drops from 139 to 42.

Second, the proposer still reaches tasks it has never seen. Nothing in the corpus squares a difference, yet `(x - 1)^2` is found, and found sooner, because smoothing leaves every production a nonzero probability and the corpus still teaches useful habits about `*` and `-`.

Third, a prior is not free. On `2x + 3` the uniform order wins, 16 candidates to 59, because it stumbles early on `(+ x (+ x 3))`, an equivalent program the corpus considers odd. The learned proposer returns `(+ (* 2 x) 3)` instead: the form a person would write, and the form its corpus taught it. LLMs show the same trait at scale. They are fast on idiomatic code and slower, or wrong, on code unlike what they were trained on, and the verifier is what keeps "wrong" from reaching the user.

### From the toy to an LLM

Three differences separate this example from an LLM-guided synthesizer, and none of them changes the architecture.

- **Conditioning.** This proposer ranks programs the same way for every task. An LLM reads the task (examples, a docstring, failing tests) and conditions its proposals on it. DreamCoder's recognition network does the same for a grammar like this one: it maps a task's examples to production weights.
- **Sampling.** An LLM samples programs rather than sorting a fixed list. Sampling scales to spaces too large to sort, at the cost of duplicate proposals and no guarantee of covering the space.
- **The verifier.** Here the verifier checks a full specification over `x = 0..9`. Production systems verify with test suites, type checkers, proof assistants, or scoring functions. The weaker the verifier, the more the system's correctness depends on the proposer, and the less of this chapter's guarantee survives.

Chapter 4 noted that LLM coding agents run the CEGIS loop with a test suite as the verifier. Chapter 8 looks at FunSearch, AlphaEvolve, AlphaGeometry, and AlphaProof, which use the same split of a learned proposer and a strict checker to find new mathematics.

## Running the Examples

Each is an explicit-`provide` module with `(module+ main ...)` for narration and `(module+ test ...)` for checks; `require` is silent:

```bash
cd source-code/05-neurosymbolic-paradigm
racket 01-why-deep-learning-insufficient.rkt
racket 02-neural-symbolic-synergy.rkt
racket 03-differentiable-reasoning.rkt
racket 04-compositional-reasoning-case-study.rkt
racket 05-learned-proposer.rkt
raco test .   # no demo output on require
```

The printouts narrate each stage: perceptron convergence and failure on XOR, the lookup-table baseline versus the digit recognizer plus `+`, the gradient trace on the Socratic syllogism, the discovery of `(+ x x)` from a single example, and the uniform-versus-learned proposal counts. Reading the outputs alongside the code shows exactly where the neural and symbolic responsibilities meet.

## Wrap Up

The neurosymbolic paradigm is not a single algorithm but a family of design patterns for combining learning and logic. Pure neural networks interpolate but do not extrapolate, and they memorize rather than compose. Pure symbolic systems verify and compose but struggle with noisy, high-dimensional perception. Neurosymbolic systems place a symbolic reasoning stage after a neural perceptual stage, smooth the interface so gradients can flow, and let each half play to its strengths.

The chapter's examples build up this design pattern in five steps. The perceptron failures in `01-why-deep-learning-insufficient.rkt` show what goes wrong with pure function approximation. The digit-addition pipeline in `02-neural-symbolic-synergy.rkt` shows how a clean perceptual/symbolic seam fixes the extrapolation failure. The soft logic engine in `03-differentiable-reasoning.rkt` shows how the seam can be made differentiable so beliefs are trained jointly with the logic. And the program-synthesis case study in `04-compositional-reasoning-case-study.rkt` shows the full neurosymbolic loop returning an executable, composable artifact, not just a label or a number. Finally, `05-learned-proposer.rkt` moves the learned model inside the search: a probabilistic grammar orders the candidates, CEGIS verifies them, and the same split of duties underlies LLM-guided synthesis. The next chapter, *Neurosymbolic Architectures & Algorithms*, moves from these worked examples to the deployed systems—Logic Tensor Networks, Logical Neural Networks, NeurASP, and Differentiable ILP—that industrialize the same ideas.
