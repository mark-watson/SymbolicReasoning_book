#lang racket

;;; SAT/SMT-Style Constraint Solving for Synthesis
;;;
;;; We model a small synthesis problem as a set of constraints over
;;; unknown program components, then solve by systematic assignment
;;; search (a toy stand-in for a real SAT/SMT solver).
;;;
;;; Problem: find constants a and b in {0..3} such that the program
;;;   f(x) = a*x + b
;;; satisfies the input/output examples
;;;   f(0) = 1, f(1) = 3, f(2) = 5
;;;
;;; Real systems (Rosette, Sketch) hand these constraints to Z3 or a
;;; SAT solver; here we implement the same check-and-search loop by hand.

;; Candidate space
(define domain '(0 1 2 3))

;; Examples as (input . output) pairs
(define examples '((0 . 1) (1 . 3) (2 . 5)))

;; The parameterized program ("sketch" with holes a and b)
(define (f a b x) (+ (* a x) b))

;; A constraint is satisfied when the program agrees with all examples
(define (satisfies-all? a b)
  (andmap (lambda (ex)
            (= (f a b (car ex)) (cdr ex)))
          examples))

;; Solve: enumerate the hole assignments (what a SAT solver does for us)
(define (solve-constraints)
  (for*/first ((a domain)
               (b domain)
               #:when (satisfies-all? a b))
    (list a b)))

;; Show each example check for a candidate
(define (trace-candidate a b)
  (display (format "  Try a=~a b=~a: " a b))
  (for ((ex examples))
    (display (format "f(~a)=~a " (car ex) (f a b (car ex)))))
  (displayln (if (satisfies-all? a b) "  SAT" "  UNSAT")))

(displayln "=== Constraint-Based Synthesis: f(x) = a*x + b ===")
(newline)
(display "Examples: ") (displayln examples)
(display "Hole domains: a, b in ") (displayln domain)
(newline)

(displayln "Search trace (first candidates):")
(trace-candidate 0 0)
(trace-candidate 0 1)
(trace-candidate 1 0)
(trace-candidate 2 0)

(newline)
(let ((sol (solve-constraints)))
  (if sol
      (begin
        (displayln (format "Solution found: a = ~a, b = ~a"
                           (car sol) (cadr sol)))
        (displayln (format "Synthesized program: f(x) = ~a*x + ~a"
                           (car sol) (cadr sol)))
        (displayln "Verification against examples:")
        (for ((ex examples))
          (displayln (format "  f(~a) = ~a (expected ~a) ~a"
                             (car ex)
                             (f (car sol) (cadr sol) (car ex))
                             (cdr ex)
                             (if (= (f (car sol) (cadr sol) (car ex)) (cdr ex))
                                 "OK" "FAIL")))))
      (displayln "UNSAT: no values of a and b satisfy the examples.")))

(newline)
(displayln "A real SMT solver encodes the same problem with uninterpreted")
(displayln "functions and integer arithmetic; the loop above is what the")
(displayln "solver's decision procedure automates.")
