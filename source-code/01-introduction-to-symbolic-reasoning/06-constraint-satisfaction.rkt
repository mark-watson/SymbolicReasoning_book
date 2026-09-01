#lang racket

;;; Simple Constraint Satisfaction Problem Solver
;;; Map coloring for Australia, now with immutable backtracking

(provide regions
         colors
         constraints
         satisfies?
         solve-map-coloring
         show-solution)

;; Example: Map coloring for Australia
(define regions '(wa nt sa q nsw v))
(define colors '(red green blue))

;; Adjacency constraints
(define constraints
  '((wa nt) (wa sa) (nt sa) (nt q) (sa q) (sa nsw) (sa v) (q nsw) (nsw v)))

;; Check if constraints are satisfied by assignment (hash region -> color)
;; constraints param allows reuse for other CSPs
(define (satisfies? assignment [cs constraints])
  (for/and ([c cs])
    (match-define (list a b) c)
    (define ca (hash-ref assignment a #f))
    (define cb (hash-ref assignment b #f))
    (or (not ca) (not cb) (not (equal? ca cb)))))

;; Backtracking with immutable hashes; returns hash or #f
(define (solve-map-coloring [regs regions] [cols colors] [cs constraints])
  (define (backtrack assigned remaining)
    (if (null? remaining)
        assigned
        (let ([next (car remaining)]
              [rem (cdr remaining)])
          (for/or ([color cols])
            (define assigned* (hash-set assigned next color))
            (and (satisfies? assigned* cs)
                 (backtrack assigned* rem))))))
  (backtrack (hash) regs))

;; Display solution; handles #f gracefully
(define (show-solution sol [regs regions])
  (if (not sol)
      (displayln "  No solution")
      (for ([r regs])
        (displayln (format "  ~a = ~a" r (hash-ref sol r "unassigned"))))))

(module+ main
  (displayln "=== Constraint Satisfaction: Map Coloring ===")
  (displayln (format "Regions: ~a" regions))
  (displayln (format "Colors: ~a" colors))
  (displayln "")

  (let ([sol (solve-map-coloring)])
    (if sol
        (begin
          (displayln "Solution found:")
          (show-solution sol))
        (displayln "No solution found")))

  (displayln "")
  (displayln "This example uses immutable hashes and for/or backtracking.")
  (displayln "More complex problems add forward checking and MRV heuristics."))

(module+ test
  (require rackunit)
  (define sol (solve-map-coloring))
  (check-not-false sol)
  (check-true (satisfies? sol))
  ;; All regions assigned
  (for ([r regions]) (check-not-false (hash-ref sol r #f)))
  ;; Unsatisfiable with 2 colors
  (check-false (solve-map-coloring regions '(red green) constraints))
  ;; satisfies? with wildcard (unassigned vars are ok)
  (check-true (satisfies? (hash 'wa 'red)))
  (check-false (satisfies? (hash 'wa 'red 'nt 'red))))
