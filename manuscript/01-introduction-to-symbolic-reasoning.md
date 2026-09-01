# Chapter 1: Introduction to Symbolic Reasoning

Symbolic reasoning forms the bedrock of classical artificial intelligence. Before statistical methods dominated the landscape, AI researchers built systems that manipulated explicit symbols according to formal rules. This chapter introduces the fundamental concepts that underpin symbolic AI and explains why these ideas remain essential for building systems capable of genuine reasoning.

All code examples for this chapter are in `source-code/01-introduction-to-symbolic-reasoning/`. Each example is a self-contained Racket module that you can run directly to see the concepts in action. Common helpers live in `source-code/utils/` and in the convenience aggregator `source-code/utils.rkt`.

## Shared Utilities

The book now factors repeated helpers into `source-code/utils/`. Earlier drafts copied the same function into many files. The factored version keeps one definition and imports it everywhere else. This saves maintenance and removes drift bugs.

```
source-code/
  utils.rkt              ; convenience re-export
  utils/
    string.rkt           ; string-reverse
    math.rkt             ; dot, sigmoid, hamming, clamp01
    logic.rkt            ; t-and, t-and-list, t-not, t-impl
    eval.rkt             ; eval-arith, ast-size helpers
```

The code below shows the real files. Use them as a reference for later chapters.

### `utils/string.rkt`

```racket
#lang racket
(provide string-reverse string-trim*)

(define (string-reverse s)
  (unless (string? s)
    (raise-argument-error 'string-reverse "string?" s))
  (list->string (reverse (string->list s))))
```

All string chapters used to define their own `string-reverse`. The logic was correct but four copies drifted in comments and argument checks. Now they import this one.

```racket
(require "../utils/string.rkt")
;; later: (string-reverse "hello") => "olleh"
```

### `utils/math.rkt`

```racket
#lang racket
(provide dot sigmoid hamming clamp01)

(define (dot xs ys)
  (unless (= (length xs) (length ys))
    (raise-argument-error 'dot "equal-length lists" 0 xs ys))
  (apply + (map * xs ys)))

(define (sigmoid x) (/ 1.0 (+ 1.0 (exp (- x)))))

(define (hamming xs ys)
  (length (filter (lambda (p) (not (equal? (car p) (cdr p))))
                  (map cons xs ys))))

(define (clamp01 x) (max 0.0 (min 1.0 x)))
```

`dot` and `sigmoid` appeared in three places in Chapter 6 (LTN, NeurASP, dILP). `hamming` appeared in the digit recognition example in Chapter 5. `clamp01` appeared in the causal model in Chapter 8. Each had small differences in error handling. The utils version raises a clear error when vector lengths differ, which is the most common mistake when adding a new embedding dimension.

Import it where needed:

```racket
(require "../utils/math.rkt")
;; later: (dot '(1 2) '(3 4)) => 11
```

In files two levels deep the require is `../../utils/math.rkt` or `../utils/math.rkt`. The aggregator shortens that.

### `utils/logic.rkt`

```racket
#lang racket
(provide t-and t-and-list t-not t-impl)

(define (t-and x y) (* x y))
(define (t-and-list xs) (if (null? xs) 1.0 (apply * xs)))
(define (t-not x) (- 1.0 x))
(define (t-impl x y) (+ 1.0 (- x) (* x y)))
```

Chapters 5 and 6 each defined product t-norms and Reichenbach implication separately. The definitions were the same but some used `t-and` for two args and others defined `t-and` for a list. The utils module provides both. `t-and-list` returns `1.0` for the empty case, which matches the logical identity for universal quantification over an empty domain.

```racket
(require "../utils/logic.rkt")
;; later: (t-impl 0.9 0.2) => 0.28  ; implication is weak when premise is strong and conclusion is weak
```

### `utils/eval.rkt`

```racket
#lang racket
(provide eval-arith eval-arith-env eval-expr-with-x ast-size ast-size-extended)

(define (eval-arith expr env)
  (match expr
    [(? number? n) n]
    [(? symbol? s) (hash-ref env s s)]
    [`(+ ,a ,b) (+ (eval-arith a env) (eval-arith b env))]
    [`(- ,a ,b) (- (eval-arith a env) (eval-arith b env))]
    [`(* ,a ,b) (* (eval-arith a env) (eval-arith b env))]
    [_ (raise-argument-error 'eval-arith "arith expr" expr)]))

(define (ast-size e)
  (match e
    [(or (? number? ) (? symbol?)) 1]
    [`(,(or '+ '- '*) ,a ,b) (+ 1 (ast-size a) (ast-size b))]
    [_ 1]))
```

At least ten chapter files evaluated arithmetic s-expressions over `+`, `*`, `-`, and a variable `x`. The code was copied with small drift in error messages and in how `x` was bound (sometimes a hash, sometimes an alist). `eval-arith` binds `x` through a hash table. Helpers like `ast-size` count nodes for parsimony pressure in Chapters 8 and 9.

Not every evaluator collapses to one function. Files that need division, `sq`, `pow2`, `pow3`, or `ite` extend `eval-arith` locally. That is intentional: utils holds the common core, chapter files hold the grammar-specific extension.

### `utils.rkt` Aggregator

```racket
#lang racket
(provide (all-from-out "utils/string.rkt")
         (all-from-out "utils/math.rkt")
         (all-from-out "utils/logic.rkt")
         (all-from-out "utils/eval.rkt"))

(require "utils/string.rkt" "utils/math.rkt" "utils/logic.rkt" "utils/eval.rkt")
```

If a chapter file needs helpers from several utils, it can import the aggregator with one line:

```racket
(require "../utils.rkt")        ; from source-code/01-.../file.rkt
(require "../../utils.rkt")     ; from deeper paths
;; or the directory form
(require "../utils/math.rkt")   ; single concern
```

### Why Chapter 1 Owns This Section

Chapter 1 is where the book first asks you to run code. It is the right place to show where shared code lives and how to import it. The pattern after this chapter is the same everywhere:

- Library code at the top, with an explicit `provide` list.
- `require` for the utils it actually uses, plus `racket/match`, `racket/dict`, or `racket/set` where needed.
- Demo and print statements inside `(module+ main ...)`, so `(require "file.rkt")` does not produce output.
- Unit tests inside `(module+ test ...)` with `rackunit`, runnable as `raco test .`.

### How to Use the Utils in Your Own Code

Try a small REPL exercise. From `source-code/01-introduction-to-symbolic-reasoning/`:

```racket
(require "../utils/string.rkt" "../utils/math.rkt" "../utils/logic.rkt")

(string-reverse "live")        ; => "evil"
(dot '(0.9 0.1) '(0.6 0.6))   ; => 0.6
(t-impl 0.9 0.2)               ; => 0.28
```

Each utils file raises `exn:fail:contract` with a named argument on misuse, so mistakes point to the caller rather than to a deep stack trace.

## Propositional and Predicate Logic

At the heart of symbolic reasoning lies formal logic. Propositional logic deals with simple true/false statements and logical connectives like AND, OR, NOT, and IMPLIES. Predicate logic extends this with variables, quantifiers, and relations, enabling us to express complex statements about objects and their properties.

The example file `01-propositional-logic.rkt` builds a propositional evaluator without copying logic helpers from other files:

```racket
#lang racket
(require racket/dict racket/match)

(provide logical-and logical-or logical-not logical-implies logical-iff
         evaluate make-environment truth-table truth-table-display)

(define (logical-and a b) (if (and a b) #t #f))
(define (logical-or a b)  (if (or a b) #t #f))
(define (logical-not a)   (if a #f #t))
(define (logical-implies a b) (if a b #t))

(define (truth-table vars expr)
  (for/list ([i (in-range (expt 2 (length vars)))])
    (define assignment
      (for/list ([v vars] [k (in-naturals)])
        (if (bitwise-bit-set? i k) #t #f)))
    (list assignment (evaluate expr (make-environment vars assignment)))))

(define (evaluate expr env)
  (match expr
    [(== #t) #t]
    [(== #f) #f]
    [(? symbol? s) (dict-ref env s #f)]
    [`(not ,a) (logical-not (evaluate a env))]
    [`(and ,a ,b) (logical-and (evaluate a env) (evaluate b env))]
    [`(or ,a ,b) (logical-or (evaluate a env) (evaluate b env))]
    [_ (raise-argument-error 'evaluate "propositional expr" expr)]))
```

Key concepts demonstrated:
- **Propositional operators**: AND, OR, NOT, IMPLIES, IFF with strict boolean returns
- **Evaluation**: Computing truth values for formulas given variable assignments
- **Truth tables**: Pure function returning a list of rows, with `truth-table-display` for printing

The fix over the early draft is small but important. The first version used `(eq? a #t)` for `or` and `(not (eq? a #f))` for `and`, which disagreed on truthy values such as `1`. The current version uses Racket truth uniformly: anything except `#f` counts as true, and each connective returns `#t` or `#f` only.

## Automated Theorem Proving and Logic Programming

Once we have formal representations, we need methods to derive new knowledge from existing knowledge. Automated theorem proving encompasses algorithms that can prove logical statements automatically. Logic programming turns logical inference into a computational paradigm where programs are sets of logical clauses.

### Unification

The unification algorithm (`02-unification.rkt`) finds substitutions that make two terms identical:

```racket
(define (subst-lookup var env)
  (let loop ([v var])
    (define p (assq v env))
    (if p (loop (cdr p)) v)))

(define (unify x y env)
  (let ([x-val (subst x env)] [y-val (subst y env)])
    (cond
      [(equal? x-val y-val) env]
      [(var? x-val) (if (occurs? x-val y-val env) (error 'unify "occurs check") (cons (cons x-val y-val) env))]
      [(and (pair? x-val) (pair? y-val))
       (let ([env1 (unify (car x-val) (car y-val) env)])
         (unify (cdr x-val) (cdr y-val) env1))]
      [else (error 'unify "clash ~a vs ~a" x-val y-val)])))
```

Key concepts:
- **Chained substitution**: `subst-lookup` now chases `?x -> ?y -> a` so bindings compose
- **Occurs check**: Preventing infinite structures such as `?x = (f ?x)`
- **Proper cdr handling**: Dotted pairs unify both `car` and `cdr`, not just the `car` path
- **Parameterized error model**: `unify` raises `exn:fail`; callers that want `#f` wrap it with `with-handlers`

### Forward Chaining

The forward chaining engine in `03-forward-chaining.rkt` derives new facts from rules without global mutation at require time:

```racket
(define current-facts (make-parameter '()))
(define (add-fact! fact) (current-facts (cons fact (current-facts))))
(define (clear-kb!) (current-facts '()))

(define (forward-chain rules facts max-iterations #:trace? [trace? #f])
  (let loop ([all-facts facts] [iter 0])
    (if (>= iter max-iterations) all-facts
        (let ([all-new (append-map (lambda (r) (derive-once r all-facts)) rules)])
          (if (null? all-new) all-facts
              (loop (append all-new all-facts) (+ iter 1)))))))
```

`current-facts` is a parameter, not a plain `set!` global, so tests can isolate knowledge bases and `(require "03-forward-chaining.rkt")` no longer prints at load time. Demos live inside `(module+ main ...)`. `derive-once` uses `append-map` instead of mutating `set!` and `append`, and the trace is opt-in via `#:trace?`.

## Knowledge Representation and Reasoning

Raw logic alone is insufficient for real-world applications. We need structured ways to represent knowledge about complex domains. The semantic network example (`04-semantic-network.rkt`) shows how to build graph-based knowledge representations:

```racket
(struct triple (subj pred obj) #:transparent)
(define current-network (make-parameter '()))

(define (find-triples #:subj [subj #f] #:pred [pred #f] #:obj [obj #f])
  (for/list ([t (current-network)]
             #:when (and (or (not subj) (eq? (triple-subj t) subj))
                         (or (not pred) (eq? (triple-pred t) pred))
                         (or (not obj)  (eq? (triple-obj t) obj))))
    t))

(define (inherits? obj pred val)
  (for/or ([ancestor (set->list (isa-closure-set obj))])
    (member val (find-all ancestor pred))))
```

Key concepts:
- **Triple store**: Knowledge as `triple` structs, not plain lists
- **Wildcard queries**: `find-triples` accepts `#f` as wildcard; `query` builds on it
- **Inheritance**: `inherits?` checks the isa closure instead of manual `describe` inspection
- **Correct closure**: `isa-closure-set` uses a visited set, so diamonds and cycles do not duplicate or loop

## Search, Planning, and Constraint Satisfaction

Many AI problems can be framed as search through a space of possible states or solutions. The examples demonstrate:

### Search Algorithms (`05-search-algorithms.rkt`)

The updated version factors BFS and DFS into one search with a combiner:

```racket
(define (search start goal combiner #:trace? [trace? #f])
  (cond [(equal? start goal) (list start)]
        [else (let loop ([frontier (list (list start))] [visited (make-hash)]) ...)]))

(define (bfs start goal #:trace? [trace? #f])
  (search start goal (lambda (new rest) (append rest new)) #:trace? trace?))

(define (dfs start goal #:trace? [trace? #f])
  (search start goal (lambda (new rest) (append new rest)) #:trace? trace?))
```

The graph is noted as directed, `search` handles `start == goal` without looping, and printing is opt-in via `#:trace?`. Path display uses `(reverse path)` so logs read forward.

### Constraint Satisfaction (`06-constraint-satisfaction.rkt`)

The CSP solver now uses immutable hashes and `for/or`:

```racket
(define (satisfies? assignment [cs constraints])
  (for/and ([c cs])
    (match-define (list a b) c)
    (define ca (hash-ref assignment a #f))
    (define cb (hash-ref assignment b #f))
    (or (not ca) (not cb) (not (equal? ca cb)))))

(define (solve-map-coloring [regs regions] [cols colors] [cs constraints])
  (define (backtrack assigned remaining)
    (if (null? remaining) assigned
        (for/or ([color cols])
          (define assigned* (hash-set assigned (car remaining) color))
          (and (satisfies? assigned* cs) (backtrack assigned* (cdr remaining))))))
  (backtrack (hash) regs))
```

`satisfies?` takes its constraint list as a parameter, so the same checker works for N-Queens or other CSPs. `backtrack` threads immutable hashes, which removes the stale binding bug from the mutable version. `show-solution` handles `#f`.

---

Symbolic reasoning complements modern machine learning by providing explicit, interpretable representations of knowledge and inference. The examples in this chapter demonstrate the core techniques that form the foundation for program synthesis and neurosymbolic AI systems explored in later chapters.

## Running the Examples

All examples are self-contained Racket modules. The shared helpers require no external packages.

```bash
cd source-code/01-introduction-to-symbolic-reasoning
racket 01-propositional-logic.rkt   # Propositional logic evaluator
racket 02-unification.rkt           # Unification algorithm
racket 03-forward-chaining.rkt      # Forward chaining inference
racket 04-semantic-network.rkt      # Semantic networks
racket 05-search-algorithms.rkt      # Search algorithms (BFS/DFS)
racket 06-constraint-satisfaction.rkt # CSP solver

# run as libraries without side effects
racket -e '(require "01-propositional-logic.rkt") (displayln (evaluate (quote (and x y)) (quote ((x . #t) (y . #f)))))'

# run tests for this chapter
raco test .
```

Each file has `(module+ main ...)` for demos and `(module+ test ...)` for `rackunit` checks. Running `raco test` in any `source-code/` subdirectory executes the tests without printing demos.
