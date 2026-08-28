# Introduction to Symbolic Reasoning

Symbolic reasoning forms the bedrock of classical artificial intelligence. Before statistical methods dominated the landscape, AI researchers built systems that manipulated explicit symbols according to formal rules. This chapter introduces the fundamental concepts that underpin symbolic AI and explains why these ideas remain essential for building systems capable of genuine reasoning.

All code examples for this chapter are in `source-code/01-introduction-to-symbolic-reasoning/`. Each example is a self-contained Racket module that you can run directly to see the concepts in action.

## Propositional and Predicate Logic

At the heart of symbolic reasoning lies formal logic. Propositional logic deals with simple true/false statements and logical connectives like AND, OR, NOT, and IMPLIES. Predicate logic extends this with variables, quantifiers, and relations, enabling us to express complex statements about objects and their properties.

The example file `01-propositional-logic.rkt` demonstrates how to build a simple propositional logic evaluator in Racket:

```racket
#lang racket

;; Logical connectives
(define (logical-and a b)
  (and (not (eq? a #f)) (not (eq? b #f))))

(define (evaluate expr env)
  (cond
    ((symbol? expr) (dict-ref env expr #f))
    ((and (list? expr) (= (length expr) 3))
     (let ((op (car expr))
           (a (cadr expr))
           (b (caddr expr)))
       (case op
         ((and) (logical-and (evaluate a env) (evaluate b env)))
         ...))))
```

Key concepts demonstrated:
- **Propositional operators**: AND, OR, NOT, IMPLIES, IFF
- **Evaluation**: Computing truth values for formulas given variable assignments
- **Truth tables**: Systematic enumeration of all possible assignments

Understanding these formal systems is crucial because they provide the mathematical foundation for representing and manipulating knowledge in a machine-interpretable form.

## Automated Theorem Proving and Logic Programming

Once we have formal representations, we need methods to derive new knowledge from existing knowledge. Automated theorem proving encompasses algorithms that can prove logical statements automatically. Logic programming turns logical inference into a computational paradigm where programs are sets of logical clauses.

### Unification

The unification algorithm (demonstrated in `02-unification.rkt`) is central to logic programming. It finds substitutions that make two terms identical:

```racket
(define (unify x y env)
  (let ((x-val (subst x env))
        (y-val (subst y env)))
    (cond
      ((eq? x-val y-val) env)
      ((var? x-val)
       (if (occurs? x-val y-val env)
           (error "Occurs check failed")
           (cons (cons x-val y-val) env)))
      ...)))
```

Key concepts:
- **Pattern matching**: Matching complex structures with variables
- **Occurs check**: Preventing infinite structures
- **Substitution application**: Applying bindings to create unified terms

### Forward Chaining

The forward chaining engine in `03-forward-chaining.rkt` demonstrates how to derive new facts from rules:

```racket
(define (forward-chain rules facts max-iterations)
  (let loop ((all-facts facts) (iter 0))
    (let ((new (derive-facts rules all-facts)))
      (if (null? new)
          all-facts
          (loop (append new all-facts) (+ iter 1))))))
```

This approach derives new facts by repeatedly applying inference rules until no new facts can be generated. It's a form of data-driven reasoning that contrasts with goal-directed backward chaining.

## Knowledge Representation and Reasoning

Raw logic alone is insufficient for real-world applications. We need structured ways to represent knowledge about complex domains. The semantic network example (`04-semantic-network.rkt`) shows how to build graph-based knowledge representations:

```racket
(define %network '())

(define (add-triple! subj pred obj)
  (set! %network (cons (list subj pred obj) %network)))

(define (describe obj)
  (let ((results '()))
    (for ((triple %network))
      (when (eq? (car triple) obj)
        (set! results (cons (list (cadr triple) (caddr triple)) results))))
    results))
```

Key concepts:
- **Triple store**: Knowledge represented as (subject, predicate, object) triples
- **Inheritance**: Using ISA relationships to infer properties
- **Queries**: Asking questions about represented knowledge

These representation schemes enable systems to reason about complex, structured knowledge in ways that mirror human conceptual organization.

## Search, Planning, and Constraint Satisfaction

Many AI problems can be framed as search through a space of possible states or solutions. The examples demonstrate:

### Search Algorithms (`05-search-algorithms.rkt`)

Standard search methods for exploring solution spaces:

```racket
(define (bfs start goal)
  (let loop ((q (list (list start))) (visited '()))
    ...))
```

The example includes BFS and DFS implementations, showing how these algorithms systematically explore graphs to find paths between nodes.

### Constraint Satisfaction (`06-constraint-satisfaction.rkt`)

The CSP solver demonstrates how to find assignments to variables that satisfy a set of constraints:

```racket
(define (solve-map-coloring)
  (backtrack (make-hash) regions))

(define (satisfies? assignment)
  (for/and ((c constraints))
    (let ((a (car c)) (b (cadr c)))
      (let ((ca (hash-ref assignment a #f))
            (cb (hash-ref assignment b #f)))
        (if (and ca cb) (not (equal? ca cb)) #t))))
```

The classic map coloring example shows how constraints limit the search space and how backtracking search can find valid colorings efficiently.

---

Symbolic reasoning complements modern machine learning by providing explicit, interpretable representations of knowledge and inference. The examples in this chapter demonstrate the core techniques that form the foundation for program synthesis and neurosymbolic AI systems explored in later chapters.

## Running the Examples

All examples are self-contained Racket modules. Run them from the source-code directory:

```bash
cd source-code/01-introduction-to-symbolic-reasoning
racket 01-propositional-logic.rkt   # Propositional logic evaluator
racket 02-unification.rkt           # Unification algorithm
racket 03-forward-chaining.rkt      # Forward chaining inference
racket 04-semantic-network.rkt      # Semantic networks
racket 05-search-algorithms.rkt      # Search algorithms (BFS/DFS)
racket 06-constraint-satisfaction.rkt # CSP solver
```

These examples use only the Racket standard library, requiring no external dependencies. Each demonstrates a fundamental concept in symbolic AI that will be extended in subsequent chapters to build more sophisticated program synthesis systems.
