#lang racket

;;; SAT/SMT-Style Constraint Solving for Synthesis
;;; Find a,b in {0..3} so f(x)=a*x+b matches f(0)=1,f(1)=3,f(2)=5.
;;; Real solvers (Z3, CVC5) handle this without enumeration; we
;;; enumerate to show the same SAT check.

(provide domain
         examples
         f
         satisfies-all?
         solve-constraints
         trace-candidate)

(define domain '(0 1 2 3))
(define examples '((0 . 1) (1 . 3) (2 . 5)))

(define (f a b x) (+ (* a x) b))

(define (satisfies-all? a b [exs examples])
  (andmap (lambda (ex) (= (f a b (car ex)) (cdr ex))) exs))

(define (solve-constraints [dom domain] [exs examples])
  (for*/first ([a dom] [b dom] #:when (satisfies-all? a b exs))
    (list a b)))

(define (trace-candidate a b [exs examples])
  (display (format "  Try a=~a b=~a: " a b))
  (for ([ex exs]) (display (format "f(~a)=~a " (car ex) (f a b (car ex)))))
  (displayln (if (satisfies-all? a b exs) " SAT" " UNSAT")))

(module+ main
  (displayln "=== Constraint-Based Synthesis: f(x) = a*x + b ===")
  (newline)
  (displayln (format "Examples: ~a" examples))
  (displayln (format "Hole domains: a, b in ~a" domain))
  (newline)
  (displayln "Search trace (first candidates):")
  (trace-candidate 0 0)
  (trace-candidate 0 1)
  (trace-candidate 1 0)
  (trace-candidate 2 0)
  (newline)
  (match (solve-constraints)
    [#f (displayln "UNSAT: no values of a and b satisfy the examples.")]
    [(list a b)
     (displayln (format "Solution found: a = ~a, b = ~a" a b))
     (displayln (format "Synthesized program: f(x) = ~a*x + ~a" a b))
     (displayln "Verification:")
     (for ([ex examples])
       (displayln (format "  f(~a) = ~a (expected ~a) ~a"
                          (car ex) (f a b (car ex)) (cdr ex)
                          (if (= (f a b (car ex)) (cdr ex)) "OK" "FAIL"))))])
  (newline)
  (displayln "A real SMT solver encodes uninterpreted functions and integer")
  (displayln "arithmetic; the loop above is what the solver automates."))

(module+ test
  (require rackunit)
  (check-equal? (solve-constraints) '(2 1))
  (check-true (satisfies-all? 2 1))
  (check-false (satisfies-all? 0 0))
  (check-false (solve-constraints '(0 1) '((0 . 0) (1 . 10)))))
