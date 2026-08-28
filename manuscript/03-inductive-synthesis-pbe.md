# Inductive Synthesis & Programming by Example (PBE)

Programming by Example (PBE) represents one of the most intuitive and practical approaches to program synthesis. Instead of writing formal specifications or logical descriptions of desired behavior, users provide concrete input-output examples. The synthesis system must then infer a program that correctly transforms the given inputs to the desired outputs.

All code examples for this chapter are in `source-code/03-inductive-synthesis-pbe/`.

## The Program Synthesis Problem

Synthesis problems are formally defined by specifications that describe:
- **Examples**: Input-output pairs demonstrating desired behavior  
- **Grammar**: What operations and language constructs are allowed
- **Verification**: How to check that a candidate program satisfies the specification

The file `04-problem-formulation.rkt` demonstrates this formal approach:

```racket
(struct synthesis-problem
  (name examples grammar verify metadata))

(define (make-problem name examples grammar verify (meta '()))
  (synthesis-problem name examples grammar verify meta))
```

## Enumerative Search

The most straightforward approach to PBE is to systematically generate and test candidate programs until finding one that satisfies all examples.

### Bottom-Up Enumeration

The example `01-enumerative-search.rkt` demonstrates bottom-up program enumeration, starting with simple expressions and combining them:

```racket
(define (generate-programs max-size)
  (if (= max-size 1)
      (list 0 1 2 3 4 5)
      (append base
              (for*/list ((a (generate-programs (max 1 (- max-size 1))))
                          (b (generate-programs (max 1 (- max-size 1))))
                          (op '(+ *)))
                (list op a b)))))
```

This approach faces the challenge of combinatorial explosion—the space of possible programs grows rapidly with program size.

## Version Space Algebras

Version spaces provide a compact representation of all programs consistent with the given examples. The file `02-version-space.rkt` demonstrates:

```racket
(define (vs-update example old-vs)
  (let ((input (car example))
        (output (cadr example))
        (candidates (vs-candidates old-vs)))
    (let ((filtered
           (filter (lambda (c) (predict-for-example c input output))
                   candidates)))
      (vs (vs-desc old-vs) filtered))))
```

As new examples arrive, the version space shrinks, focusing search on plausible candidates.

## Stochastic and Evolutionary Search

When systematic search becomes intractable, stochastic methods use randomness and population-based search. The genetic programming example (`03-genetic-programming.rkt`) evolves programs through mutation and crossover:

```racket
(define (fitness program examples)
  (let ((error 0))
    (for ((ex examples))
      (set! error (+ error 
                     (abs (- (eval-expr program (hash 'x input)) 
                            (cadr ex))))))
    (- error)))

(define (evolve population examples generations)
  (let loop ((gen 0) (pop population))
    ...))
```

Fitness evaluation drives selection toward better solutions.

## Practical Applications

PBE has driven many practical successes:
- **Data Wrangling**: Excel's Flash Fill and related tools
- **Code Repair**: Learning repair patterns from examples  
- **Scientific Discovery**: Finding explanatory models from data

The Flash Fill demo (`04-flash-fill-demo.rkt`) shows basic transformation learning, though sophisticated PBE systems require richer DSLs and search strategies for tasks like name formatting.

---

PBE is a foundational technique for program synthesis. The next part of this book explores deductive and constraint-based methods that derive programs from formal specifications with correctness guarantees.

## Running the Examples

```bash
cd source-code/03-inductive-synthesis-pbe
racket 01-pbe-string-transform.rkt      # String transformation learning
racket 02-version-space.rkt            # Version space operations  
racket 03-genetic-programming.rkt       # Genetic programming
racket 04-flash-fill-demo.rkt          # Flash Fill-style demo
```