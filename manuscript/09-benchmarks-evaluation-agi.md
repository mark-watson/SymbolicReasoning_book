# Benchmarks, Evaluation, and the Path to AGI

Previous chapters showed how to build synthesis systems that learn, reason, and compose. This chapter asks a different question: how do we know whether those systems are actually any good? Benchmarks and evaluation frameworks are the bridge between the research program of program synthesis and the broader ambition of artificial general intelligence (AGI). A synthesizer that solves one curated example is interesting; a synthesizer that solves a battery of tasks with a measurable generalization gap is interesting *and* trustworthy.

The examples in this chapter are in `source-code/09-benchmarks-evaluation-agi/` and are written in plain Racket so that the harnesses and metrics are visible rather than tucked inside a benchmarking library. They build up four ideas: a framework for reporting per-task metrics, an ARC-style task for testing abstraction, a SCAN-style benchmark for compositional generalization, and a leaderboard that compares learning strategies by their generalization gap.

## Evaluating General Intelligence: Per-Task Metrics

The example `01-evaluation-framework.rkt` sets the baseline. Rather than report a single binary outcome ("solved" / "failed"), we measure four numbers for each task:

```racket
(struct result (name train-acc test-acc prog))
```

The four numbers we care about for any synthesis benchmark are:

1. **Train accuracy** — did the synthesizer find a program consistent with the data it saw?
2. **Test accuracy** — does that program generalize to held-out inputs?
3. **Program size** — how parsimonious is the explanation? A compact program is more likely to have captured the underlying rule than a memorized lookup table.
4. **Candidates considered** — how efficient was the search? A synthesizer that brute-forces 10,000 candidates to find a 3-node program is doing something qualitatively different from one that finds it after 8 candidate evaluations.

The benchmark suite in the example consists of five small algebraic tasks (identity, double, square, increment, two-x-plus-one), each defined by a train set and a held-out test set. The synthesizer is a simple candidate-list enumerator over a fixed set of expressions:

```racket
(define (synthesize examples)
  (let loop ((rest (candidates)) (n 0))
    (cond
      [(null? rest) (cons #f n)]
      [(andmap (lambda (ex)
                 (= (eval-expr (car rest) (car ex)) (cdr ex)))
               examples)
       (cons (car rest) n)]
      [else (loop (cdr rest) (+ n 1))])))
```

The harness walks each task, runs the synthesizer, and assembles per-task reports:

```racket
(define (run-task task)
  (match-define (list name train test) task)
  (define result (synthesize train))
  (define prog (car result))
  (define considered (cdr result))
  (if (not prog) ...
      (let* ((train-acc (/ (count ... ) (length train)))
             (test-acc  (/ (count ... ) (length test))))
        (hash 'name name 'status 'solved
              'prog prog
              'train-acc train-acc 'test-acc test-acc
              'size (size prog) 'considered considered))))
```

Running the example produces a per-task report and an aggregate summary:

```
  identity: solved
    prog = x  (size 1, considered 0)
    train-acc=1  test-acc=1
  double: solved
    prog = (+ x x)  (size 3, considered 7)
    train-acc=1  test-acc=1
  ...

Solved 5 / 5 tasks
Average train accuracy:  1.0
Average test accuracy:   1.0
Average program size:    3.0
Average candidates tried:7.8
```

This shape matters: for AGI evaluation we want per-task visibility into correctness, generalization, parsimony, and search cost, not a single leaderboard number that hides the distinction between a memorizer and a reasoner.

## A Key Benchmark: ARC in Miniature

The Abstraction and Reasoning Corpus (ARC) is the canonical benchmark for testing "fluid intelligence" in machines: each task presents two or three small input/output grid pairs and asks the system to apply the discovered rule to a held-out test grid. The point is that the rules are not in any training distribution; you have to infer them from nearly no evidence.

The example `02-arc-style-task.rkt` implements a 1-D analogue. The grid is a list of small integers, and the DSL provides six candidate transformations: `identity`, `reverse`, `sort`, `sort-desc`, `inc-each`, and `double-each`.

```racket
(define dsl
  (list (cons 'identity   t-identity)
        (cons 'reverse    t-reverse)
        (cons 'sort       t-sort)
        (cons 'sort-desc  t-sort-desc)
        (cons 'inc-each   t-inc-each)
        (cons 'double     t-double-each)))
```

Given two training pairs, the synthesizer finds every DSL entry that is consistent with both:

```racket
(define (solve-arc train-pairs)
  (filter (lambda (entry)
            (andmap (lambda (pair)
                      (equal? ((cdr entry) (car pair)) (cdr pair)))
                    train-pairs))
          dsl))
```

For the chosen training pairs the answer is uniquely `reverse`. The system then applies the discovered transformation to a held-out test input and checks the prediction:

```
Train pairs: (((1 4 2 3) 3 2 4 1) ((2 3 4 1) 1 4 3 2))
Consistent transformations: (reverse)
  reverse predicts (2 3 1 5) on test input (5 1 3 2) (expected (2 3 1 5)) -> CORRECT
```

This tiny example captures the evaluation pattern ARC uses: very few training pairs, a held-out test, and a requirement that the system commit to a specific transformation. The same machinery scales to richer grid DSLs, larger training sets, and full ARC problems.

## Compositional Generalization: A SCAN-Style Gap

ARC tests *novelty* (a rule never seen before); SCAN and similar benchmarks test *compositionality*: the ability to generalize to longer or structurally richer commands than any seen during training.

The example `03-compositional-benchmark.rkt` builds a 1-D SCAN analogue. Commands are sequences of atoms from `{walk look jump run}` combined with `and` (sequencing) and `twice` (repetition). The training set covers only short commands (length ≤ 2 tokens of meaning); the test set requires longer compositions such as `(walk and look) twice`, which expects the output `(walk look walk look)`.

Two synthesizers are compared. The **length-bounded synthesizer** expands only the first two tokens of the input and is therefore structurally incapable of producing the four-element test outputs:

```racket
(define (length-bounded-synth tokens bounded)
  (if (<= (length tokens) bounded)
      (expand-command tokens)
      (expand-command (take tokens bounded))))
```

The **compositional synthesizer** is a small recursive parser for the grammar

```
expr     :=  seq [twice]
seq      :=  primary (and primary)*
primary  :=  walk | look | jump | run
```

which evaluates any composition and therefore composes past the training distribution. Running the example:

```
--- Length-bounded synthesizer (max depth 2) ---
  (walk and look twice) -> (walk) (expected (walk look walk look)) FAIL
  (jump and run twice) -> (jump) (expected (jump run jump run)) FAIL
--- Compositional synthesizer (recursive parse) ---
  (walk and look twice) -> (walk look walk look) (expected ...) OK
  (jump and run twice)  -> (jump run jump run)   (expected ...) OK
```

The gap between the two strategies is the gap between systems that memorize lengths and systems that model grammar. That is the SCAN question in one slide.

## Generalization-Gap Leaderboard

The final example aggregates these ideas into a small leaderboard. We run three learning strategies across a battery of three tasks (identity, double, square) and report train accuracy, test accuracy, and the *generalization gap* `train - test`. The example `04-generalization-gap-leaderboard.rkt` defines the runners:

- **Nearest-neighbor memorization** wraps a closure that always returns the value of the closest training input.
- **Simple grammar** enumerates `{x, 1, 2, 3, x+1, 2x, 3x}` — enough for identity and double but not square.
- **Rich grammar** adds `x*x`, `2x+1`, and `x*x + x`.

The leaderboard printing function computes per-task accuracy and averages:

```racket
(define (display-results label runs)
  (displayln (format "--- ~a ---" label))
  (for ((r runs))
    (displayln (format "  ~a: train ~a  test ~a"
                       (result-name r)
                       (exact->inexact (result-train-acc r))
                       (exact->inexact (result-test-acc r)))))
  (define gavg (lambda (acc)
                 (/ (apply + (map acc runs)) (length runs))))
  ...)
```

The output is a clean demonstration of what each metric means:

```
--- Nearest-neighbor memorization ---
  identity: train 1.0  test 0.0
  double: train 1.0  test 0.0
  square: train 1.0  test 0.0
  avg train-acc = 1.0, avg test-acc = 0.0, avg gap = 1.0
--- Simple grammar  (no square) ---
  identity: train 1.0  test 1.0
  double: train 1.0  test 1.0
  square: train 0.0  test 0.0
  avg train-acc = 0.67, avg test-acc = 0.67, avg gap = 0.0
--- Rich grammar    (with square) ---
  identity: train 1.0  test 1.0
  double: train 1.0  test 1.0
  square: train 1.0  test 1.0
  avg train-acc = 1.0, avg test-acc = 1.0, avg gap = 0.0
```

The memorizer has the pathological gap of `1.0`; it scored everything on the training set because the test inputs are exactly what it never saw. The simple grammar has zero gap but limited coverage: it cannot represent square, so it scores `0` everywhere on that task. The rich grammar has both full coverage and zero gap—the only strategy that actually solves the benchmark.

This pattern—report train, report test, and compute the gap—is the core of any meaningful claims about progress toward AGI. Without it, "90% accuracy" tells you nothing about whether the system memorized or generalized. With it, we can rank approaches and measure real improvement.

## Running the Examples

```bash
cd source-code/09-benchmarks-evaluation-agi
racket 01-evaluation-framework.rkt
racket 02-arc-style-task.rkt
racket 03-compositional-benchmark.rkt
racket 04-generalization-gap-leaderboard.rkt
```

Each prints a narrated trace: per-task metrics for the evaluation framework, the unique reverse-rule and its held-out prediction for ARC, the contrast between bounded and compositional parsing for SCAN, and the three-strategy leaderboard for the generalization gap.

## Wrap Up

Evaluation is the empirical backbone of any AGI-flavored claim. A synthesis system that cannot be benchmarked cannot be improved, and a benchmark that reports only accuracy cannot distinguish memorization from understanding. The four examples in this chapter cover the four pillars of a useful evaluation:

- **Per-task metrics** (train/test accuracy, size, search cost) make behavior visible at the task level.
- **ARC-style tasks** test abstraction from scarce evidence.
- **SCAN-style tests** expose compositional generalization.
- **Gap-based leaderboards** aggregate strategies and make overfitting explicit.

Taken together, these show that program synthesis is not just a technique for writing programs but a testbed for measuring one of the most elusive properties of intelligence: the ability to learn a rule from two examples and apply it correctly on the hundredth. The research program that succeeds on these benchmarks—particularly on tasks like ARC, which resist memorization—will have taken a real step toward general intelligence.
