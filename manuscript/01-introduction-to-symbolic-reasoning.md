# Chapter 1: Introduction to Symbolic Reasoning

*Part I — Foundations of Symbolic AI and Program Synthesis.*

Symbolic reasoning forms the bedrock of classical artificial intelligence. Before statistical and neural network based methods dominated the landscape, AI researchers built systems that manipulated explicit symbols according to formal rules. This chapter introduces the fundamental concepts that underpin symbolic AI and explains why these ideas remain essential for building systems capable of genuine reasoning.

All code examples for this chapter are in `source-code/01-introduction-to-symbolic-reasoning/`. Each example is a self-contained Racket module that you can run directly to see the concepts in action. Later chapters share small helpers (string, math, logic, and expression evaluation) factored into `source-code/utils/`; the final section of this chapter, *Shared Utilities*, gives that module map once you have seen the examples that use it.

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

The latest version of this code uses Racket truth uniformly: anything except `#f` counts as true, and each connective returns `#t` or `#f` only.

Output looks like:

```
$ racket 01-propositional-logic.rkt 
=== Propositional Logic Examples ===
P AND Q with x=#t, y=#f:
#f

P OR Q with x=#t, y=#f:
#t

P IMPLIES Q with x=#t, y=#f:
#f

P IFF Q with x=#t, y=#f:
#f

NOT P with x=#t:
#f

(x OR y) AND (x IMPLIES y) with x=#t, y=#f:
#f

Truth table for (x OR y) AND (x IMPLIES y):
(#f #f) => #f
(#t #f) => #f
(#f #t) => #t
(#t #t) => #t

Note: table is #f for (#f #f) and (#t #f), #t for (#f #t) and (#t #t).
```

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

Program output looks like:

```
$ racket 02-unification.rkt 
=== Unification Examples ===
Unify (?x) with (a):
{?x = a}

Unify (?x ?y) with (a b):
{?y = b, ?x = a}

Unify (?x ?y ?x) with (a b a):
{?y = b, ?x = a}
Resolved ?x:
a
Resolved ?y:
b

Unify (f ?x) with (f (g a)):
{?x = (g a)}
Resolved ?x:
(g a)

Unify (?x loves ?y) with (mary loves john):
{?y = john, ?x = mary}
Resolved ?x:
mary
Resolved ?y:
john

Unify (?x ?x) with (a b) - expecting failure:
unify: clash: a vs b

Unify (?x . ?y) with (a . b):
{?y = b, ?x = a}

Chain ?x->?y, ?y->a:
resolve ?x = a (should be a)
```

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

Here is sample output:

```
$ racket 03-forward-chaining.rkt 
=== Forward Chaining Example ===
Initial facts:
  (parent tom mary)
  (parent ann sue)
  (parent bob ann)
  (parent tom bob)

Iteration 0: Derived 2 new facts: ((grandparent bob sue) (grandparent tom ann))

Grandparent facts:
  (grandparent bob sue)
  (grandparent tom ann)

=== Transitive Closure Example ===
Initial facts:
  (edge d e)
  (edge c d)
  (edge b c)
  (edge a b)

Iteration 0: Derived 4 new facts: ((connected d e) (connected c d) (connected b c) (connected a b))
Iteration 1: Derived 3 new facts: ((connected c e) (connected b d) (connected a c))
Iteration 2: Derived 2 new facts: ((connected b e) (connected a d))
Iteration 3: Derived 1 new facts: ((connected a e))

All connected pairs:
  (connected a e)
  (connected b e)
  (connected a d)
  (connected c e)
  (connected b d)
  (connected a c)
  (connected d e)
  (connected c d)
  (connected b c)
  (connected a b)

```

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

BFS and DFS are one search parameterized by a combiner. The full loop from `05-search-algorithms.rkt`:

```racket
(define (search start goal combiner #:trace? [trace? #f])
  (cond
    [(equal? start goal) (list start)]
    [else
     (define visited (make-hash))
     (define (mark-visited! n) (hash-set! visited n #t))
     (define (visited? n) (hash-has-key? visited n))
     (mark-visited! start)
     (let loop ([frontier (list (list start))])
       (cond
         [(null? frontier) #f]
         [else
          (define path (car frontier))
          (define node (car path))
          (define rest (cdr frontier))
          (if (equal? node goal)
              (reverse path)
              (let* ([nbs (filter-not visited? (get-neighbors node))]
                     [new-paths (map (lambda (n) (cons n path)) nbs)])
                (for-each mark-visited! nbs)
                (loop (combiner new-paths rest))))]))]))

(define (bfs start goal #:trace? [trace? #f])
  (search start goal (lambda (new rest) (append rest new)) #:trace? trace?))

(define (dfs start goal #:trace? [trace? #f])
  (search start goal (lambda (new rest) (append new rest)) #:trace? trace?))
```

Paths grow by consing onto the front, so the found path is reversed on return and traces read forward. The graph is directed, `search` handles `start == goal` without looping, and printing is opt-in via `#:trace?`. The combiner is the whole difference: BFS appends new paths after the old frontier (a queue), DFS puts them in front (a stack).

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

## Shared Utilities

You may have noticed that several examples above and in later chapters need the same small functions: a string reverse, a dot product, a product t-norm, an arithmetic s-expression evaluator. Earlier drafts copied these into each file, and the copies drifted — different argument checks, different comments, one outright arity bug. The book now factors them into `source-code/utils/`, one definition each, imported everywhere else:

```
source-code/
  utils.rkt              ; convenience re-export (see below)
  utils/
    string.rkt           ; string-reverse, string-trim*
    math.rkt             ; dot, sigmoid, hamming, clamp01
    logic.rkt            ; t-and, t-and-list, t-not, t-impl
    eval.rkt             ; eval-arith, ast-size helpers
```

Highlights from the four modules, rather than their full source (the files themselves are short and worth reading):

- `string-reverse` raises a contract error on non-strings. Four chapters import it instead of defining their own.
- `dot` checks equal lengths before multiplying — the most common mistake when adding a new embedding dimension in Chapter 6.
- `t-and-list` returns `1.0` for the empty case, matching the logical identity for universal quantification over an empty domain in the LTN example.
- `eval-arith` binds variables through a hash table, ending the hash-vs-alist drift between copies; `ast-size` counts AST nodes for the parsimony scores of Chapters 8 and 9.

Not every evaluator collapses to one function. Files needing division, `sq`, `pow2`, `pow3`, or `ite` extend `eval-arith` locally: utils holds the common core, chapter files hold the grammar-specific extension.

If a file needs helpers from several utils at once, the aggregator re-exports all four:

```racket
(require "../utils.rkt")        ; one-line form, re-exports everything
(require "../utils/math.rkt")   ; or single concern
```

Try it in a REPL from any chapter directory:

```racket
(require "../utils/string.rkt" "../utils/math.rkt" "../utils/logic.rkt")

(string-reverse "live")        ; => "evil"
(dot '(0.9 0.1) '(0.6 0.6))    ; => 0.6
(t-impl 0.9 0.2)               ; => 0.28 ; weak: strong premise, weak conclusion
```

Each utils file raises `exn:fail:contract` with a named argument on misuse, so mistakes point to the caller rather than to a deep stack trace.

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
