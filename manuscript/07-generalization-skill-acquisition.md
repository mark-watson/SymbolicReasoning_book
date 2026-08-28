# Generalization & Autonomous Skill Acquisition

A synthesis system is truly useful only when it can go beyond the specific examples it was trained on. This chapter examines how to build systems that generalize systematically and compositionally, reuse learned abstractions instead of rediscovering them, adapt online to new tasks at test time, and ultimately acquire new skills autonomously. The code examples are in `source-code/07-generalization-skill-acquisition/`, and they are written in plain Racket so that each search and learning loop is explicit.

## Generalizing Beyond the Training Distribution

Machine learning systems often excel on data that resembles their training set but fail catastrophically when inputs shift. In program synthesis this is especially problematic: the goal is a program that is correct for all inputs, not just a narrow sample. True generalization in this setting has three components:

- **Systematic generalization**: combining known primitives in novel ways
- **Compositional generalization**: understanding how operations compose to build complex behaviors
- **Few-shot generalization**: learning a new task from a handful of examples

The example `01-generalization-beyond-training.rkt` illustrates the difference between memorization and generalization with a simple modular arithmetic task. The hidden function is `f(x) = (x + 1) mod 4`, and the training set is restricted to `x = 0,1,2,3`.

A nearest‑neighbor baseline does not learn the function at all; it simply returns the value of the closest training point:

```racket
(define (nn-predict x examples)
  (let ((best (argmin (lambda (ex) (abs (- x (car ex)))) examples)))
    (cdr best)))
```

For an unseen input `x = 4`, the nearest neighbor is `3`, so the baseline predicts `0`—a result that appears plausible (the task is cyclic) but is derived from proximity, not from the underlying rule. In contrast, the synthesizer enumerates a small expression grammar and returns the first program that matches all training points:

```racket
(define (synthesize examples depth)
  (findf (lambda (e) (satisfies? e examples))
         (gen-exprs depth)))
```

Because the grammar includes `mod4` and arithmetic operators, the synthesizer finds `(mod4 (+ x 1))`. That program is *compositional*: it applies a known primitive (`+1`) and then wraps it in `mod4`. Once it is discovered, it generalizes to every integer input. Running the example shows that the synthesized program matches the hidden function on the held‑out inputs 4 through 8, while the nearest‑neighbor baseline can only guess.

## Compositional Abstractions and Reusable Modules

Human programmers do not write sorting routines from scratch every time; they build libraries of functions and compose them. Synthesis systems that learn to create reusable abstractions enjoy the same advantage: instead of enumerating a vast space of primitive combinations, they can search space of high‑level compositions.

The example `02-compositional-abstractions.rkt` demonstrates macro learning, a simple form of library learning. We begin with three primitives—`id`, `inc`, and `double`—and solve two tasks:

```racket
(define task1 '((0 . 1) (1 . 2) (2 . 3)))      ;; inc
(define task2 '((0 . 0) (1 . 2) (2 . 4)))      ;; double
```

The synthesizer enumerates compositions of the primitives up to a given length:

```racket
(define (synthesize examples max-depth atoms)
  (let loop ((depth 1))
    ...
    (let ((candidates
           (apply cartesian-product (make-list depth atoms))))
      ...)))
```

For task1 it discovers `(inc)`, and for task2 it discovers `(double)`. After these solutions are found, the system notices that the composition `double ∘ inc` is useful. It then adds a macro `macro-inc-then-double` to the library and can solve a harder task3—where the correct behavior is `double ∘ inc`—with a single lookup, even though the program space without the macro would require a search of depth two.

The output shows the concrete advantage:

```
Task3 (double ∘ inc): examples ((0 . 2) (1 . 4) (2 . 6))
  Without macro (depth 2 search): (inc double)
  With macro (depth 1 search):    (macro)
```

By compressing a commonly used composition into a reusable unit, the synthesizer reduces the effective search space and can tackle increasingly complex problems. This mirrors the way modern synthesis systems maintain libraries of learned snippets and use them to scale to larger domains.

## Test-Time Adaptation and Reasoning

Most learning systems are trained once offline and then frozen. Program synthesis offers a different model: adapt at test time by synthesizing a program specific to the current context. This is especially valuable when data are scarce but each new input must be handled correctly.

The example `03-test-time-adaptation.rkt` implements online synthesis of a simple linear model. The hidden function is `y = a*x + b`, and the system receives a stream of input‑output examples. After each example it synthesizes the best `(a, b)` pair, making the model immediately available for the next prediction:

```racket
(define (synthesize-on-the-fly examples)
  (for*/first ((a domain)
               (b domain)
               #:when (andmap (lambda (ex)
                                (= (f a b (car ex)) (cdr ex)))
                              examples))
    (list a b)))
```

The online loop uses this synthesizer repeatedly:

```racket
(define (online-synthesis stream)
  (let loop ((examples '()) (rest stream) (step 1))
    ...
    (let* ((pair (car rest))
           (examples* (append examples (list pair)))
           (model (synthesize-on-the-fly examples*)))
      ...)))
```

Because the system returns an explicit model `(a . b)`, it can be applied immediately to any new input without retraining. When the stream arrives as `((0 . 1) (1 . 3) (2 . 5))`, the synthesizer first proposes `0*x + 1`, then `2*x + 1`, and remains at `2*x + 1` after the third step. The final model correctly predicts `f(4) = 9`, illustrating how test‑time synthesis turns a stream of raw pairs into a reusable, general artifact.

## Program Synthesis for Autonomous Skill Acquisition

The ultimate goal of synthesis research is not just to solve a fixed set of tasks but to build systems that acquire new capabilities autonomously over time. In this framing, skills are programs that can be discovered, given names, stored in a library, and composed into more complex skills.

The example `04-skill-acquisition.rkt` implements a tiny skill library. Skills are Racket functions stored in a mutable association list. The system begins with an empty library and then synthesizes two simple skills from examples:

```racket
(define double-examples '((1 . 2) (2 . 4) (3 . 6)))
(define double-prog (synthesize-skill double-examples 1))
(add-skill! 'double (lambda (x) (eval-expr double-prog x)))

(define square-examples '((1 . 1) (2 . 4) (3 . 9)))
(define square-prog (synthesize-skill square-examples 1))
(add-skill! 'square (lambda (x) (eval-expr square-prog x)))
```

The synthesizer used here enumerates a small set of arithmetic programs and returns the first one that matches the examples. Once `double` and `square` are in the library, the system composes them into a new skill:

```racket
(define (compose-skills name1 name2 new-name)
  (let ((f (get-skill name1))
        (g (get-skill name2)))
    (add-skill! new-name (lambda (x) (f (g x))))))

(compose-skills 'double 'square 'two-x-squared)
```

The composed skill `two-x-squared` computes `2*(x*x)`, and it can be evaluated on fresh inputs without any further learning. Running the example shows the full pipeline: the system discovers skills, gives them names, and then builds a new capability that did not exist in the original library.

This example is deliberately minimal, but it captures the lifecycle that any autonomous skill‑acquisition system must support: propose a candidate skill from data, validate it, store it, and then reuse it as a building block for future skills. Lifelong learning systems can repeat this loop indefinitely, gradually accumulating a richer and richer library of composable skills.

## Running the Examples

All four demonstrations are self‑contained Racket programs:

```bash
cd source-code/07-generalization-skill-acquisition
racket 01-generalization-beyond-training.rkt
racket 02-compositional-abstractions.rkt
racket 03-test-time-adaptation.rkt
racket 04-skill-acquisition.rkt
```

Each prints a narration of its search or learning loop: the contrast between nearest‑neighbor and grammar‑based synthesis on a cyclic task, the reuse of a macro in a small composition space, the online fitting of a linear model, and the acquisition and composition of skills in a toy library.

## Wrap Up

Generalization and skill acquisition are the levers that turn a synthesis system from a one‑shot pattern matcher into a flexible reasoning engine. True generalization requires compositional structure, because only compositional programs can be recombined to handle inputs that did not appear in training. Compositional abstractions matter because they shrink the search space and let the system build on its own discoveries. Test‑time adaptation matters because it lets the system respond to a new task immediately, without waiting for a new training cycle. And autonomous skill acquisition matters because it is the mechanism by which synthesis systems can grow over time, turning each solved problem into a reusable building block for the next.

The next chapter explores how these capabilities can be applied to scientific discovery, where the hypotheses to be synthesized are not small programs but potentially new models of the world.
