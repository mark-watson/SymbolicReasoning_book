# Inductive Synthesis & Programming by Example (PBE)

Programming by Example (PBE) represents one of the most intuitive and practical approaches to program synthesis. Instead of writing formal specifications or logical descriptions of desired behavior, users provide concrete input-output examples. The synthesis system must then infer a program that correctly transforms the given inputs to the desired outputs. This chapter explores the core techniques that make PBE work.

All code examples for this chapter are in `source-code/02-program-synthesis-problem/`.

## Enumerative Search: Bottom-Up and Top-Down

The most straightforward approach to PBE is to systematically generate and test candidate programs until finding one that satisfies all examples.

The example file `01-enumerative-search.rkt` demonstrates bottom-up enumeration:

```racket
(define (generate-programs max-size)
  (if (= max-size 1)
      (list 0 1 2 3 4 5)
      (let ((base (list 0 1 2 3 4 5)))
        (append base
                (for*/list ((a (generate-programs (max 1 (- max-size 1))))
                            (b (generate-programs (max 1 (- max-size 1))))
                            (op '(+ *)))
                  (list op a b))))))

(define (bottom-up-search examples max-size)
  (let ((candidates (generate-programs max-size)))
    (findf (lambda (p) (matches-examples? p examples)) candidates)))
```

This approach faces the fundamental challenge of combinatorial explosion. The space of possible programs grows rapidly with program size, as shown by the example output:

```
Programs of size 1:  (0 1 2 3 4 5)
Programs of size 2:  Sample: (0 1 2 3 4 5 (+ 0 0) (* 0 0) ...)
Programs of size 3:  Count: 12174
```

Clever pruning, type-directed search, and domain-specific heuristics can make enumeration surprisingly effective for smaller domains.

## Version Space Algebras

Version spaces provide a more structured way to represent the set of all programs consistent with the given examples. The example (`02-version-space-algebras.rkt`) demonstrates operations on these spaces:

```racket
(define (vs-intersect vs1 vs2)
  (filter (lambda (p) (member p vs2)) vs1))

(define (add-example example vs)
  (let ((input (car example))
        (output (cadr example)))
    (filter (lambda (p) (matches-example? p input output)) vs)))
```

The key idea is maintaining a compact representation of all hypotheses that are consistent with the training examples. As more examples arrive, the version space shrinks, focusing search on increasingly plausible candidates.

## Stochastic and Evolutionary Search

When systematic search becomes intractable, stochastic methods offer an alternative. The genetic programming example (`03-stochastic-search.rkt`) evolves programs through mutation, crossover, and selection:

```racket
(define (fitness program examples)
  (let ((total-error 0))
    (for ((ex examples))
      (set! total-error (+ total-error 
                              (abs (- (eval-expr program '()) 
                                     (cadr ex))))))
    (- total-error)))

(define (mutate prog)
  (cond
    ((number? prog)
     (random-ref '(0 1 2 3 4 5)))
    ((list? prog)
     (let ((pos (random 3)))
       (list-set prog pos (random-ref '(+ * -)))))))
```

These methods trade guarantees of completeness for the ability to explore vast program spaces quickly.

---

PBE has driven many practical successes in program synthesis. The next chapter explores complementary deductive approaches that leverage formal specifications and constraint solving.

## Running the Examples

```bash
cd source-code/02-program-synthesis-problem
racket 01-enumerative-search.rkt   # Bottom-up program enumeration
racket 02-version-space-algebras.rkt # Version space operations
racket 03-stochastic-search.rkt     # Genetic programming
racket 04-problem-formulation.rkt   # Formal problem specification
```
