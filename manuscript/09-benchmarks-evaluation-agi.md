# Part V: The Road Ahead

How do you tell a system that understands from one that memorized? Part V builds the tools that answer that question. You will write an evaluation harness that reports train accuracy, test accuracy, program size, and search cost for every task. You will build small ARC-style and SCAN-style tests and a leaderboard that makes the generalization gap impossible to hide. Then you will read the real ARC-AGI record against them. On ARC-AGI-2, the same LLM scores 31% on its own and 54% inside a propose-and-verify loop. On the interactive ARC-AGI-3, frontier systems scored below 1% at launch while people solved every task. The closing chapter shows where the field stands and what the systems that close the gap will likely need.

# Chapter 9: Benchmarks, Evaluation, and the Path to AGI



Previous chapters showed how to build synthesis systems that learn, reason, and compose. This chapter asks a different question: how do we know whether those systems are actually any good? Benchmarks and evaluation frameworks are the bridge between the research program of program synthesis and the broader ambition of artificial general intelligence (AGI). A synthesizer that solves one curated example is interesting; a synthesizer that solves a battery of tasks with a measurable generalization gap is interesting *and* trustworthy.

The examples are in `source-code/09-benchmarks-evaluation-agi/` and expose their harnesses in plain Racket. Each file now uses explicit `provide`, `(module+ main ...)`/`(module+ test ...)`, and a `struct result` with named fields; `expand-command` raises a contract error on unknown tokens, and `synth->fn` distinguishes `no-program` (no coverage) from `0.0` accuracy.

## Evaluating General Intelligence: Per-Task Metrics

The example `01-evaluation-framework.rkt` sets the baseline. Rather than report a single binary outcome ("solved" / "failed"), we measure four numbers for each task:

```racket
(struct result (name train-acc test-acc prog))
```

The four numbers we care about for any synthesis benchmark are:

1. **Train accuracy**: did the synthesizer find a program consistent with the data it saw?
2. **Test accuracy**: does that program generalize to held-out inputs?
3. **Program size**: how parsimonious is the explanation? A compact program is more likely to have captured the underlying rule than a memorized lookup table.
4. **Candidates tried**: how efficient was the search? A synthesizer that brute-forces 10,000 candidates to find a 3-node program is doing something qualitatively different from one that finds it after 8 candidate evaluations.

The benchmark suite in the example consists of five small algebraic tasks (identity, double, square, increment, two-x-plus-one), each defined by a train set and a held-out test set. The synthesizer is a simple candidate-list enumerator over a fixed set of expressions:

```racket
(define (synthesize examples)
  (let loop ([rest (candidates)] [tried 1])
    (cond [(null? rest) (cons #f (- tried 1))]
          [(andmap (lambda (ex) (= (eval-expr (car rest) (car ex)) (cdr ex))) examples)
           (cons (car rest) tried)]
          [else (loop (cdr rest) (+ tried 1))])))
```

`tried` counts every candidate the loop evaluates, including the one that matched, so a hit on the first candidate reports `1`, not `0`.

The harness walks each task, runs the synthesizer, and assembles per-task reports. The full `run-task` from `01-evaluation-framework.rkt`, whose `result` struct carries the four metrics:

```racket
(struct result (name status prog train-acc test-acc size tried) #:transparent)

(define (run-task task)
  (match-define (list name train test) task)
  (match-define (cons prog tried) (synthesize train))
  (if (not prog)
      (result name 'fail #f 0.0 0.0 0 tried)
      (let* ([train-correct (count (lambda (ex) (= (eval-expr prog (car ex)) (cdr ex))) train)]
             [test-correct  (count (lambda (ex) (= (eval-expr prog (car ex)) (cdr ex))) test)])
        (result name 'solved prog (/ train-correct (length train)) (/ test-correct (length test)) (size prog) tried))))
```

Running the example produces a per-task report and an aggregate summary:

```
  identity: solved
    prog = x  (size 1, tried 1)
    train-acc=1  test-acc=1
  double: solved
    prog = (+ x x)  (size 3, tried 8)
    train-acc=1  test-acc=1
  ...

Solved 5 / 5 tasks
Average train accuracy:  1.0
Average test accuracy:   1.0
Average program size:    3.0
Average candidates tried: 8.8
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
(define (consistent-with-train? fn [train-pairs train])
  (andmap (lambda (pair) (equal? (fn (car pair)) (cdr pair))) train-pairs))

(define (solve-arc train-pairs)
  (filter (lambda (entry) (consistent-with-train? (cdr entry) train-pairs)) dsl))
```

For the chosen training pairs the answer is uniquely `reverse`. The system then applies the discovered transformation to a held-out test input and checks the prediction:

```
Train pairs: (((1 4 2 3) 3 2 4 1) ((2 3 4 1) 1 4 3 2))
Consistent transformations: (reverse)
  reverse predicts (2 3 1 5) on test input (5 1 3 2) (expected (2 3 1 5)) -> CORRECT
```

This tiny example captures the evaluation pattern ARC uses: very few training pairs, a held-out test, and a requirement that the system commit to a specific transformation. The same machinery scales to richer grid DSLs, larger training sets, and full ARC problems.

## ARC in Practice: Versions, the ARC Prize, and Real Scores

The 1-D example above treats ARC as one fixed benchmark. It is not. Since François Chollet released the Abstraction and Reasoning Corpus in 2019, it has grown into a series of benchmarks, each built after systems began to solve the last one, and an annual prize that serves as the main public record of how synthesis, search, and LLM methods compare.

**ARC-AGI-1** is the original corpus, with 400 public training tasks and 400 public evaluation tasks, plus hidden sets for scoring. **ARC-AGI-2** (2025) keeps the grid format but asks for deeper composition: rules that interact, symbols whose meaning depends on context, and several rules applied at once. Its makers tested every task on people; each one was solved by at least two human test-takers in two attempts or fewer, in a study of over 400 members of the public. **ARC-AGI-3** (launched March 25, 2026) breaks from the static format. Each task is a turn-based game with no instructions, rules, or stated goal. The agent must explore, work out what the game does and what counts as winning, and carry what it learns into harder levels. At launch, people could solve every environment, and frontier AI systems scored below 1%.

The **ARC Prize** runs on Kaggle, where entries must run offline with fixed compute on a private task set, so a score measures the method rather than the size of a model behind an API. A grand prize, for 85% on the private set, has not been claimed.

- **ARC Prize 2024** (ARC-AGI-1). The best private-set score rose from 33% to 55.5%. MindsAI posted the 55.5% but did not open-source its method, so the prize went to the ARChitects at 53.5%. The prize's technical report credits two families of methods: deep-learning-guided program synthesis and test-time training, the fine-tuning of a model on each task's own examples (the test-time adaptation idea of Chapter 7).
- **OpenAI o3** (December 2024, outside the Kaggle rules). A preview of o3 scored 75.7% on the ARC-AGI-1 semi-private set at the prize's high-efficiency setting, and 87.5% with about 172 times the compute. The ARC Prize team later noted that the released o3 is a different model from the one tested.
- **ARC Prize 2025** (ARC-AGI-2, March 26 to November 3, 2025, 1,455 teams). NVARC won with 24.03% on the private set at about $0.20 per task, ahead of the ARChitects (16.53%) and MindsAI (12.64%). NVARC combined a test-time-trained model in the ARChitects' style, a large body of synthetic tasks, and parts of the Tiny Recursive Model (TRM). TRM won the paper award: a 7-million-parameter network that reached 45% on ARC-AGI-1 and 8% on ARC-AGI-2.

Representative scores, as reported by the ARC Prize team through the 2025 results:

| Benchmark | System | Approach | Score |
|---|---|---|---|
| ARC-AGI-1 | the ARChitects (2024 winner) | test-time-trained LLM, Kaggle limits | 53.5% |
| ARC-AGI-1 | OpenAI o3 preview | reasoning LLM, many samples | 75.7% (87.5% at ~172x compute) |
| ARC-AGI-1 | TRM | tiny recursive network, 7M parameters | 45% |
| ARC-AGI-2 | Gemini 3 Pro | LLM alone, $0.81 per task | 31% |
| ARC-AGI-2 | Claude Opus 4.5 (Thinking, 64k) | LLM alone, $2.20 per task | 37.6% |
| ARC-AGI-2 | Poetiq refinement on Gemini 3 Pro | LLM inside a refinement loop, about $30 per task | 54% |
| ARC-AGI-2 | NVARC (2025 winner) | test-time training plus synthetic data, Kaggle limits | 24.03% |
| ARC-AGI-3 | frontier models at launch | LLM agents | below 1% (people: 100%) |

Scores on these benchmarks change month to month, and newer results exist than this table shows. Check the leaderboard at <https://arcprize.org> for current numbers, and compare rows with care: Kaggle entries run under tight compute limits on a private set, while the commercial results come from a semi-private set with no such limit.

Two patterns in the table matter for this book. First, the gains come from hybrids. The same LLM scores 31% alone and 54% inside a refinement loop that proposes a solution, checks it against the task's training pairs, and revises it. That loop is CEGIS from Chapter 4, with the training pairs as the verifier and the LLM as the proposer of Chapter 5. The prize's 2025 report also singles out evolutionary program synthesis entries that generate and verify candidate programs in the same way. Second, the drop at each new version shows what the benchmark is for. Methods tuned to ARC-AGI-1 lost most of their score on ARC-AGI-2, and agents that handle ARC-AGI-2 score almost nothing on ARC-AGI-3. Each version measures the gap between skill on known kinds of task and the ability to pick up a new kind, which is the generalization gap of this chapter at the scale of a field.

## Compositional Generalization: A SCAN-Style Gap

ARC tests *novelty* (a rule never seen before); SCAN and similar benchmarks test *compositionality*: the ability to generalize to longer or structurally richer commands than any seen during training.

The example `03-compositional-benchmark.rkt` builds a 1-D SCAN analogue. Commands are sequences of atoms from `{walk look jump run}` combined with `and` (sequencing) and `twice` (repetition). As in SCAN, `and` binds more loosely than `twice`, so `walk and look twice` means `walk`, then `look twice`, and expects `(walk look look)`. The training set holds single commands, `x and y` pairs, and `x twice`. The test set combines `and` with `twice` in one command, which no training example does. The second test also uses `run`, which appears in the command table but in no training example.

Two strategies are compared. The **length-bounded baseline** ignores structure. It keeps the known commands, expands the first two, and drops the modifiers:

```racket
(define (length-bounded-synth tokens bounded)
  (define known (filter (lambda (t) (assoc t command-table)) tokens))
  (expand-command (take known (min bounded (length known)))))
```

The **compositional interpreter** is a small recursive-descent parser for the grammar

```
seq      :=  term (and term)*
term     :=  primary [twice]
primary  :=  walk | look | jump | run
```

```racket
(define (parse-expr tokens)
  (define (parse-primary toks)
    (and (pair? toks)
         (assoc (car toks) command-table)
         (cons (car toks) (cdr toks))))
  (define (parse-term toks)
    (define p (parse-primary toks))
    (cond [(not p) #f]
          [(and (pair? (cdr p)) (eq? (cadr p) 'twice))
           (cons (list 'twice (car p)) (cddr p))]
          [else p]))
  (define (parse-seq toks)
    (let loop ([acc (parse-term toks)])
      (cond [(not acc) #f]
            [(and (pair? (cdr acc)) (eq? (cadr acc) 'and))
             (define rhs (parse-term (cddr acc)))
             (and rhs (loop (cons (list 'and (car acc) (car rhs)) (cdr rhs))))]
            [else acc])))
  (define s (parse-seq tokens))
  (and s (null? (cdr s)) (car s)))
```

Each inner parser returns the tree it built paired with the tokens it did not consume. `parse-expr` succeeds only when no tokens remain, so `(walk walk walk)` is a parse failure rather than a silent `walk`. The grammar puts `twice` inside `term` and `and` in `seq`, which gives `and` the lower precedence: `(walk and look twice)` parses to `(and walk (twice look))`. `eval-program` then expands the tree, and `interpret` combines the two steps.

The parser is written by hand, not learned, so the demo first checks it against the training data. Running the example:

```
Compositional interpreter reproduces all 8 train examples: #t

--- Length-bounded baseline (first 2 commands) ---
  (walk and look twice) -> (walk look) (expected (walk look look)) FAIL
  (jump and run twice) -> (jump run) (expected (jump run run)) FAIL
--- Compositional interpreter (recursive parse) ---
  (walk and look twice) -> (walk look look) (expected (walk look look)) OK
  (jump and run twice) -> (jump run run) (expected (jump run run)) OK
```

The gap between the two strategies is the gap between systems that memorize lengths and systems that model grammar. That is the SCAN question in one slide.

## Generalization-Gap Leaderboard

The final example aggregates these ideas into a small leaderboard. We run three learning strategies across a battery of three tasks (identity, double, square) and report train accuracy, test accuracy, and the *generalization gap* `train - test`. The example `04-generalization-gap-leaderboard.rkt` defines the runners:

- **Nearest-neighbor memorization** wraps a closure that always returns the value of the closest training input.
- **Simple grammar** enumerates `{x, 1, 2, 3, x+1, 2x, 3x}`, enough for identity and double but not square.
- **Rich grammar** adds `x*x`, `2x+1`, and `x*x + x`.

`eval-linear` raises an error on an expression outside its grammar, rather than returning `#f` and failing later inside `=`.

The leaderboard printing function computes per-task accuracy and averages, and `synth->fn` distinguishes a failed synthesis (`no-program`, tagged `no-coverage` in the report) from a program that scores `0.0`:

```racket
(define (synth->fn result)
  (cond [(procedure? result) result]
        [(or (symbol? result) (list? result) (number? result)) (lambda (x) (eval-linear result x))]
        [(not result) (lambda (x) 'no-program)]
        [else (lambda (x) #f)]))

(define (display-results label runs)
  (displayln (format "--- ~a ---" label))
  (for ([r runs])
    (define tag (cond [(not (result-prog r)) "no-coverage"]
                      [(procedure? (result-prog r)) "lookup table"]
                      [else (format "prog ~a" (result-prog r))]))
    (displayln (format "  ~a: train ~a  test ~a  ~a"
                       (result-name r)
                       (exact->inexact (result-train-acc r))
                       (exact->inexact (result-test-acc r))
                       tag)))
  ...)
```

The output is a clean demonstration of what each metric means:

```
--- Nearest-neighbor memorization ---
  identity: train 1.0  test 0.0  lookup table
  double: train 1.0  test 0.0  lookup table
  square: train 1.0  test 0.0  lookup table
  avg train-acc = 1.0, avg test-acc = 0.0, avg gap = 1.0
--- Simple grammar  (no square) ---
  identity: train 1.0  test 1.0  prog x
  double: train 1.0  test 1.0  prog (* x 2)
  square: train 0.0  test 0.0  no-coverage
  avg train-acc = 0.6666666666666666, avg test-acc = 0.6666666666666666, avg gap = 0.0
--- Rich grammar    (with square) ---
  identity: train 1.0  test 1.0  prog x
  double: train 1.0  test 1.0  prog (* x 2)
  square: train 1.0  test 1.0  prog (* x x)
  avg train-acc = 1.0, avg test-acc = 1.0, avg gap = 0.0
```

![Train and held-out accuracy for the three strategies](images/ch9-generalization-gap.png)

The memorizer has the pathological gap of `1.0`; it scored everything on the training set because the test inputs are exactly what it never saw. The simple grammar has zero gap but limited coverage: it cannot represent square, so it scores `0` everywhere on that task. The rich grammar has both full coverage and zero gap—the only strategy that actually solves the benchmark.

Real benchmarks show the same gap. ARC Prize scores entries on a private task set that no entrant has seen, because public tasks leak into training data and tuning choices. In 2025 the winning team, NVARC, scored 27.64% on the public leaderboard and 24.03% on the private set. The private score is the one that counts, and the difference between the two is a direct measure of how much a method fit the tasks it could see. The ARC-AGI versions above are the same idea one level up: each new version is a held-out test for the methods built on the last one.

This pattern—report train, report test, and compute the gap—is the core of any meaningful claims about progress toward AGI. Without it, "90% accuracy" tells you nothing about whether the system memorized or generalized. With it, we can rank approaches and measure real improvement.

## Running the Examples

```bash
cd source-code/09-benchmarks-evaluation-agi
racket 01-evaluation-framework.rkt
racket 02-arc-style-task.rkt
racket 03-compositional-benchmark.rkt
racket 04-generalization-gap-leaderboard.rkt
raco test .
```

Each prints a narrated trace: per-task metrics for the evaluation framework, the unique reverse-rule and its held-out prediction for ARC, the contrast between bounded and compositional parsing for SCAN, and the three-strategy leaderboard for the generalization gap.

## Wrap Up

Evaluation is the empirical backbone of any AGI-flavored claim. A synthesis system that cannot be benchmarked cannot be improved, and a benchmark that reports only accuracy cannot distinguish memorization from understanding. The four examples in this chapter cover the four pillars of a useful evaluation:

- **Per-task metrics** (train/test accuracy, size, search cost) make behavior visible at the task level.
- **ARC-style tasks** test abstraction from scarce evidence.
- **SCAN-style tests** expose compositional generalization.
- **Gap-based leaderboards** aggregate strategies and make overfitting explicit.

Taken together, these show that program synthesis is not just a technique for writing programs but a testbed for measuring one of the most elusive properties of intelligence: the ability to learn a rule from two examples and apply it correctly on the hundredth. The research program that succeeds on these benchmarks, particularly on tasks like ARC that resist memorization, will have taken a real step toward general intelligence. The ARC Prize results to date point at what that program looks like: learned models that propose, search that explores, and checks that verify, the three parts this book has built one small program at a time.
