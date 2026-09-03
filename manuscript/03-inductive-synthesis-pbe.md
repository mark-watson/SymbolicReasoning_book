# Chapter 3: Inductive Synthesis & Programming by Example (PBE)

*Part II — Core Methods in Program Synthesis.*

Programming by Example (PBE) represents one of the most intuitive approaches to synthesis: users give input-output pairs, the system infers a program. This chapter moves from the constant-only language of Chapter 2 to grammars with variables and shows three ways to search them—version spaces, evolutionary search, and FlashFill-style demonstration—using the same factored helpers as the rest of the book.

All code for this chapter is in `source-code/03-inductive-synthesis-pbe/`. `string-reverse` is imported from `source-code/utils/string.rkt`; demos are in `(module+ main ...)` and checks in `(module+ test ...)`.

## String Transformations: Fixing the DSL

`01-pbe-string-transform.rkt` now uses `match` and a correct `take`/`drop` distinction. The early draft treated `drop` as `(substring s 0 n)` twice.

```racket
(require "../utils/string.rkt")

(struct string-op (name func) #:transparent)
(define +operations+
  (list (string-op "reverse" string-reverse)
        (string-op "to-upper" string-upcase)
        (string-op "to-lower" string-downcase)
        (string-op "trim" string-trim)))

(define (eval-string-expr expr input)
  (match expr
    [(? string? s) s]
    ['input input]
    [`(concat ,args ...) (apply string-append (map (lambda (a) (eval-string-expr a input)) args))]
    [`(take ,s ,n) (substring (eval-string-expr s input) 0 n)]
    [`(drop ,s ,n) (substring (eval-string-expr s input) n)]
    [_ (raise-argument-error 'eval-string-expr "string expr" expr)]))

(define (learn-transform examples)
  (for/or ([op +operations+])
    (and (for/and ([ex examples]) (equal? ((string-op-func op) (car ex)) (cadr ex))) op)))
```

The behavior is intentionally honest: `("john smith" "smith, john")` returns `#f` because the DSL has no `split` on space. The printed message says so, and the chapter notes that a richer DSL would learn `(concat (second (split input " ")) ", " (first ...))`. `apply-operation` now takes the `string-op` struct itself (with a contract check) and the file provides an explicit export list.

## Version Space Algebras

`02-version-space.rkt` keeps the `vs` struct but now shares `string-reverse` and shows both the intersection and the sequential-filter story:

```racket
(require "../utils/string.rkt")
(struct vs (desc candidates) #:transparent)

(define (vs-update example old-vs)
  (match-define (list input output) example)
  (vs (vs-desc old-vs)
      (filter (lambda (c) (equal? (apply-operation c input) output))
              (vs-candidates old-vs))))

(define (vs-intersect vs1 vs2)
  (vs (vs-desc vs1) (filter (lambda (c) (member c (vs-candidates vs2))) (vs-candidates vs1))))
```

The demo filters `hello -> olleh` to `(reverse)` and `HELLO -> hello` to `(to-lower)` separately, shows their intersection is `()` (no primitive is both), and also shows sequential filtering `hello` then `HELLO` is `()`. `provide` is explicit and `string-reverse` is no longer redefined locally.

## Stochastic and Evolutionary Search

`03-genetic-programming.rkt` adds the variable `x` (so `f(x)=2x` can be learned) and fixes mutation/crossover to work on subtrees, matching the fix in Chapter 2:

```racket
(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [(? symbol? s) (hash-ref env s s)]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]))

(define (mutate prog) (replace-random-subtree prog (random-program 1)))
(define (crossover p1 p2)
  (if (and (list? p1) (list? p2))
      (replace-random-subtree p1 (random-ref (subtrees p2)))
      (random-ref (list p1 p2))))

(define (evolve population examples generations)
  (let loop ([gen 0] [pop population])
    (if (>= gen generations) (argmax (lambda (p) (fitness p examples)) pop)
        (let* ([scored (sort pop > #:key (lambda (p) (fitness p examples)))]
               [parents (take scored (max 2 (quotient (length scored) 2)))])
          (loop (+ gen 1) (append parents (for/list ([_ parents]) (mutate (crossover (random-ref parents) (random-ref parents))))))))))
```

The file now also evolves: `fitness` threads the input via `(hash 'x input)`, `evolve` keeps the top half as parents and breeds offspring via `crossover` + `mutate`, and a fixed `(random-seed 3)` at the top of the file makes the trace reproducible. The printed run shows the population already containing a fitness-`0` champion at generation 0 — `(- (* 3 x) (* 1 x))`, i.e. `3x - x = 2x` — which then survives elitist selection unchanged through generation 5. That is worth pausing on: with a population of only 20 random depth-2 programs over `{+, *, -}` and leaves including `x`, the right equivalence class often shows up immediately, and evolution's job becomes *keeping* it rather than discovering it. Later runs of the mutate/crossover demo at the end of the file show the operators preserving program shape.

## FlashFill Demo

`04-flash-fill-demo.rkt` is trimmed to its honest scope: the toy DSL has only whole-string ops, so phone formatting `1234567890 -> 123-456-7890` cannot be learned. The file states this explicitly, keeps the three `transformation` structs (`reverse`, `lower`, `upper`, now plus `trim`), imports `string-reverse` from utils, and uses a strict `provide` list. The test shows `flash-fill` on `HELLO -> hello` returns `"lower"` and on `john smith -> smith, john` returns `#f`.

## Running the Examples

```bash
cd source-code/03-inductive-synthesis-pbe
racket 01-pbe-string-transform.rkt   # correct take/drop, struct API
racket 02-version-space.rkt         # sequential vs intersect
racket 03-genetic-programming.rkt   # subtree mutate/crossover, with x
racket 04-flash-fill-demo.rkt       # honest FlashFill scope

# tests (no demo output)
raco test .
```

The next chapter keeps the same `eval-expr` pattern but adds proof extraction, SAT-style constraint solving, and grammar-guided search.
