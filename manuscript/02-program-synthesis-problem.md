# Chapter 2: The Program Synthesis Problem

Program synthesis asks for an executable artifact from a declarative specification. Instead of writing the program directly, you describe what it should do—examples, a logical formula, a grammar plus a verifier—and the synthesizer searches for a program that satisfies that description. This chapter makes that problem precise and shows the minimal machinery that every later technique reuses: a language, a search procedure, a way to prune the hypothesis space, and a way to state the task formally.

All code for this chapter is in `source-code/02-program-synthesis-problem/`. Common arithmetic evaluation and sizing helpers live in `source-code/utils/eval.rkt`, and string helpers in `utils/string.rkt`. Each file is a `provide`-explicit module with demos in `(module+ main ...)` and checks in `(module+ test ...)`, so `raco test .` runs without printing demos.

## Enumerative Search: Bottom-Up

The simplest synthesis loop is to generate programs in order of depth and test each one. The Chapter 2 language is intentionally constant-only (`0`–`5`, `+`, `*`, `-`, no variable `x`) so the chapter can isolate enumeration mechanics from binding.

`01-enumerative-search.rkt` now memoizes and deduplicates:

```racket
#lang racket
(require racket/match)

(provide eval-expr matches-examples? generate-programs bottom-up-search)

(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]
    [_ (raise-argument-error 'eval-expr "arith expr" expr)]))

(define generate-programs
  (let ([cache (make-hash)])
    (lambda (max-depth)
      (hash-ref! cache max-depth
        (lambda ()
          (if (= max-depth 1)
              (list 0 1 2 3 4 5)
              (let ([subs (generate-programs (- max-depth 1))])
                (remove-duplicates
                 (append (list 0 1 2 3 4 5)
                         (for*/list ([a subs] [b subs] [op '(+ * -)])
                           (list op a b))))))))))

(define (matches-examples? expr examples)
  (define val (eval-expr expr '()))
  (for/and ([ex examples]) (equal? val (cadr ex))))
```

The change from the early draft is three small fixes: `-` is included in enumeration, results are deduplicated with `remove-duplicates` so observationally equal programs are not counted twice, and the double recursion is cached so depth 3 does not recompute depth 2 twice. The argument is tree depth, not node count: depth 1 holds the 6 constants, depth 2 holds 114 programs, and depth 3 holds 38,994. The output reports the deduped count:

```
Programs of depth 1:
  (0 1 2 3 4 5)

Programs of depth 2:
  Sample: (0 1 2 3 4 5 (+ 0 0) (* 0 0) (- 0 0) (+ 0 1) (* 0 1) (- 0 1) (+ 0 2) (* 0 2) (- 0 2))

Programs of depth 3:
  Count (deduped): 38994
```

The chapter is honest about the constant-only limit. `(+ x x)` cannot be expressed here, so the full spec `f(0)=0, f(1)=2, f(2)=4, f(3)=6` fails and only a single-point spec like `((0 0))` succeeds. For that demo the input slot of the example pair is vestigial — the constant language ignores it; only the output `0` constrains the search. Chapter 3 adds `x` and the example then solves `(+ x x)`.

Clever pruning, type-directed search, and equivalence reduction make enumeration practical for small domains, but without them the cost is exponential, which is the point the chapter makes visible.

## Version Space Algebras

Version spaces keep the set of all hypotheses consistent with the examples, not just one candidate. `02-version-space-algebras.rkt` is now explicit about its algebra:

```racket
(define universal-space 'universal)
(define empty-space 'empty)
(define (singleton prog) (list 'singleton prog))

(define (singleton? vs) (and (pair? vs) (eq? (car vs) 'singleton)))
(define (normalize vs) (if (null? vs) empty-space vs))

(define (vs-intersect vs1 vs2)
  (cond
    [(eq? vs1 empty-space) empty-space]
    [(eq? vs2 empty-space) empty-space]
    [(eq? vs1 universal-space) vs2]
    [(eq? vs2 universal-space) vs1]
    [(singleton? vs1)
     (cond
       [(in-space? (cadr vs1) vs2) vs1]
       [else empty-space])]
    [(singleton? vs2)
     (cond
       [(in-space? (cadr vs2) vs1) vs2]
       [else empty-space])]
    [(and (list? vs1) (list? vs2))
     (normalize (filter (lambda (p) (member p vs2)) vs1))]
    [else empty-space]))

(define (in-space? prog vs)
  (cond
    [(eq? vs empty-space) #f]
    [(eq? vs universal-space) #t]
    [(singleton? vs) (equal? prog (cadr vs))]
    [(list? vs) (and (member prog vs) #t)]
    [else #f]))
```

`in-space?` returns strict `#t`/`#f`, not the tail that `member` returns. A singleton `(singleton p)` is itself a two-element list, so every function tests `singleton?` before `list?`. Without that order, `(in-space? 'singleton (singleton 2))` would return `#t`. `normalize` turns an empty filter result into `empty-space`, so the empty space has one representation. The demo shows the collapse that the constant-only language forces: after `f(0)=0, f(1)=2, f(2)=4, f(3)=6` the version space is `empty`, since no constant fits all four points.

## Stochastic and Evolutionary Search

When enumeration is too large, population methods trade completeness for speed. `03-stochastic-search.rkt` previously mutated by poking a random list position with a random operator, which broke arity. It now works on subtrees:

```racket
(define (subtrees prog)
  (cons prog (if (list? prog) (append (subtrees (cadr prog)) (subtrees (caddr prog))) '())))

(define (replace-random-subtree prog new-sub)
  (if (or (number? prog) (= (random 3) 0))
      new-sub
      (if (= (random 2) 0)
          (list (car prog) (replace-random-subtree (cadr prog) new-sub) (caddr prog))
          (list (car prog) (cadr prog) (replace-random-subtree (caddr prog) new-sub)))))

(define (mutate prog) (replace-random-subtree prog (random-program 1)))
(define (crossover p1 p2)
  (if (and (list? p1) (list? p2))
      (replace-random-subtree p1 (random-ref (subtrees p2)))
      (random-ref (list p1 p2))))
```

`fitness` is unchanged (negative total error) but now uses the same `eval-expr` as the other files. The dead `return` stub is removed, and `gp` uses `argmax` over fitness and keeps elites plus `crossover`/`mutate` offspring. The demo shows fitness stuck at `-8` for the constant-only `f(x)=2x` task, as it must be, because no constant can reach `0`. It then shows `mutate` and `crossover` preserving shape. The demo calls `(random-seed 42)` inside `main`, so its transcript repeats from run to run, while requiring the file leaves the global random state alone. `gp` prints its per-generation trace only when called with `#:trace? #t`.

## Formal Problem Statement

`04-problem-formulation.rkt` gives the chapter’s punchline: a synthesis task is a struct of examples, grammar, verifier, and metadata, and the string DSL bug is fixed.

```racket
(struct synthesis-problem (name examples grammar verify metadata) #:transparent)

(define (eval-string prog input)
  (match prog
    ['reverse (string-reverse (car input))]
    [`(concat ,a ,b) (string-append (eval-string a input) (eval-string b input))]
    [_ (raise-argument-error 'eval-string "string program" prog)]))
```

The draft evaluated `cadr` twice for `(concat a b)`; the fixed version uses `a` and `b` (i.e., `cadr` and `caddr` in the old `cond` form). `string-reverse` is now imported from `utils/string.rkt` so the four copies across the book converge. The `verify` lambdas close over the struct’s own examples, and `verify-candidate` guards against a `#f` verifier. An unknown program raises an error; an earlier draft returned the input list, which then broke `string-append` with a confusing message.

---

## Running the Examples

Each file prints a narrated trace when run directly and stays silent when required as a library:

```bash
cd source-code/02-program-synthesis-problem
racket 01-enumerative-search.rkt       # enumeration with dedup and memoization
racket 02-version-space-algebras.rkt  # universal/empty, strict in-space?
racket 03-stochastic-search.rkt       # subtree mutate/crossover
racket 04-problem-formulation.rkt     # problem struct and string DSL

# library use (no demo output)
racket -e '(require "01-enumerative-search.rkt") (displayln (generate-programs 1))'

# tests
raco test .
```

The next chapter adds the variable `x` and richer grammars, so the same machinery can actually learn `f(x)=2x` instead of only isolating why it cannot.
