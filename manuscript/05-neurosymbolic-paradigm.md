# The Neurosymbolic Paradigm

The previous chapter ended with a warning sign. Deductive synthesis gives beautiful guarantees, but constraint solving and theorem proving search exponentially large spaces. Purely inductive learning, by contrast, scales gracefully but learns statistical correlations without any built-in notion of correctness or compositionality. The neurosymbolic paradigm proposes to close this gap by combining the strengths of both approaches.

The core observation is simple: neural networks are remarkably good at *perception* and *pattern recognition*, while symbolic systems are remarkably good at *reasoning*, *composition*, and *verification*. A neurosymbolic system couples the two. The neural side translates raw, noisy input (pixels, text, sensor signals) into structured hypotheses. The symbolic side checks those hypotheses against logical constraints, composes them with known rules, and searches for executable programs that satisfy them. Both sides can inform each other during training, and—crucially—both sides are visible in the final artifact in a way that neither a hidden state nor a symbolic trace is alone.

All code examples for this chapter are in `source-code/05-neurosymbolic-paradigm/`. They are written in plain Racket and implement small versions of the neurosymbolic pipeline by hand, so the learning loop, the constraint checker, and the search procedure are all explicit. Shared math and logic helpers (`dot`, `hamming`, `t-and`, `t-impl`) are imported from `source-code/utils/math.rkt` and `utils/logic.rkt` so the four files no longer redefine them. Each file is an explicit-`provide` module with `(module+ main ...)` for demos and `(module+ test ...)` for `raco test`.

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

First, the perceptron fits the OR-like dataset perfectly, reaching accuracy `1` after a few passes. Second, when the network is trained only on `(0 0)`, `(0 1)`, and `(1 0)`, its prediction on the held-out `(1 1)` is checked against the true OR value `1`. The updated demo prints `Held-out prediction 1 vs true 1 -> OK` or `FAIL`, making the brittleness explicit rather than showing `?`. `dot` is now imported from `utils/math.rkt`, and the file’s `accuracy` and `show-preds` are exported with an explicit `provide`. Third, on XOR the perceptron plateaus at accuracy `1/2` no matter how many epochs it runs, because XOR is not linearly separable:

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

## Running the Examples

Each is an explicit-`provide` module with `(module+ main ...)` for narration and `(module+ test ...)` for checks; `require` is silent:

```bash
cd source-code/05-neurosymbolic-paradigm
racket 01-why-deep-learning-insufficient.rkt
racket 02-neural-symbolic-synergy.rkt
racket 03-differentiable-reasoning.rkt
racket 04-compositional-reasoning-case-study.rkt
raco test .   # no demo output on require
```

The printouts narrate each stage: perceptron convergence and failure on XOR, the lookup-table baseline versus the digit recognizer plus `+`, the gradient trace on the Socratic syllogism, and the discovery of `(+ x x)` from a single example. Reading the outputs alongside the code shows exactly where the neural and symbolic responsibilities meet.

## Wrap Up

The neurosymbolic paradigm is not a single algorithm but a family of design patterns for combining learning and logic. Pure neural networks interpolate but do not extrapolate, and they memorize rather than compose. Pure symbolic systems verify and compose but struggle with noisy, high-dimensional perception. Neurosymbolic systems place a symbolic reasoning stage after a neural perceptual stage, smooth the interface so gradients can flow, and let each half play to its strengths.

The chapter's examples build up this design pattern in four steps. The perceptron failures in `01-why-deep-learning-insufficient.rkt` show what goes wrong with pure function approximation. The digit-addition pipeline in `02-neural-symbolic-synergy.rkt` shows how a clean perceptual/symbolic seam fixes the extrapolation failure. The soft logic engine in `03-differentiable-reasoning.rkt` shows how the seam can be made differentiable so beliefs are trained jointly with the logic. And the program-synthesis case study in `04-compositional-reasoning-case-study.rkt` shows the full neurosymbolic loop returning an executable, composable artifact, not just a label or a number. The next chapter, *Neurosymbolic Architectures & Algorithms*, moves from these worked examples to the deployed systems—Logic Tensor Networks, Logical Neural Networks, NeurASP, and Differentiable ILP—that industrialize the same ideas.
