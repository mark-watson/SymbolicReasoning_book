#lang racket

;;; Simple Constraint Satisfaction Problem Solver
;;; Demonstrates constraint solving from the chapter

;; Example: Map coloring for Australia
(define regions '(wa nt sa q nsw v))
(define colors '(red green blue))

;; Adjacency constraints
(define constraints 
  '((wa nt) (wa sa) (nt sa) (nt q) (sa q) (sa nsw) (sa v) (q nsw) (nsw v)))

;; Check if constraints are satisfied by assignment
(define (satisfies? assignment)
  (let loop ((cs constraints))
    (if (null? cs)
        #t
        (let* ((c (car cs))
               (a (car c))
               (b (cadr c))
               (ca (hash-ref assignment a #f))
               (cb (hash-ref assignment b #f)))
          (if (and ca cb (equal? ca cb))
              #f
              (loop (cdr cs)))))))

;; Simple backtracking with recursion
(define (solve-map-coloring)
  (define (backtrack assigned remaining)
    (if (null? remaining)
        assigned
        (let* ((next (car remaining))
               (rem (cdr remaining))
               (colors-to-try colors))
          (define (try-colors cs)
            (if (null? cs)
                #f
                (let ((color (car cs)))
                  (hash-set! assigned next color)
                  (if (satisfies? assigned)
                      (let ((result (backtrack assigned rem)))
                        (if result
                            result
                            (try-colors (cdr cs))))
                      (begin (hash-remove! assigned next)
                             (try-colors (cdr cs)))))))
          (try-colors colors-to-try))))
  (backtrack (make-hash) regions))

;; Display solution
(define (show-solution sol)
  (for ((r regions))
    (display "  ")
    (display r)
    (display " = ")
    (displayln (hash-ref sol r))))

;; Main
(displayln "=== Constraint Satisfaction: Map Coloring ===")
(displayln "Regions: ") (displayln regions)
(displayln "Colors: ") (displayln colors)
(displayln "")

(let ((sol (solve-map-coloring)))
  (if sol
      (begin
        (displayln "Solution found:")
        (show-solution sol))
      (displayln "No solution found")))

(displayln "")
(displayln "This example demonstrates the core CSP concepts.")
(displayln "More complex problems require constraint propagation and")
(displayln "intelligent search heuristics.")
