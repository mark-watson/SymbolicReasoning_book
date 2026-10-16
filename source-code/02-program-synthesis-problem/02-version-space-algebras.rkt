#lang racket

;;; Version Space Algebras
;;; Compact representation of consistent hypothesis spaces

(provide universal-space
         empty-space
         singleton
         vs-intersect
         vs-union
         in-space?
         add-example
         matches-example?
         generate-candidates
         compose-vs)

;; The universal space (all possible programs)
(define universal-space 'universal)

;; The empty space (no programs)
(define empty-space 'empty)

;; Create a singleton space
(define (singleton prog) (list 'singleton prog))

;; A singleton is itself a list, so every list case below must test for
;; singleton first.
(define (singleton? vs) (and (pair? vs) (eq? (car vs) 'singleton)))

;; Concrete program lists use empty-space, never '(), for "no programs",
;; so there is one representation of the empty space.
(define (normalize vs) (if (null? vs) empty-space vs))

;; View a singleton or concrete space as a plain list of programs
(define (space->list vs) (if (singleton? vs) (list (cadr vs)) vs))

;; Intersection: programs in both spaces
;; NB: singleton checks come before the concrete-list check, because a
;; singleton (list 'singleton p) is itself a list and would otherwise be
;; treated as a two-element program list.
(define (vs-intersect vs1 vs2)
  (cond
    [(eq? vs1 empty-space) empty-space]
    [(eq? vs2 empty-space) empty-space]
    [(eq? vs1 universal-space) vs2]
    [(eq? vs2 universal-space) vs1]
    ;; Singleton handling: treat singleton as one-element list
    [(singleton? vs1)
     (cond
       [(in-space? (cadr vs1) vs2) vs1]
       [else empty-space])]
    [(singleton? vs2)
     (cond
       [(in-space? (cadr vs2) vs1) vs2]
       [else empty-space])]
    ;; Both are concrete lists of programs (simplified algebra)
    [(and (list? vs1) (list? vs2))
     (normalize (filter (lambda (p) (member p vs2)) vs1))]
    [else empty-space]))

;; Union: programs in either space
(define (vs-union vs1 vs2)
  (cond
    [(eq? vs1 empty-space) vs2]
    [(eq? vs2 empty-space) vs1]
    [(eq? vs1 universal-space) universal-space]
    [(eq? vs2 universal-space) universal-space]
    [(and (list? vs1) (list? vs2))
     (remove-duplicates (append (space->list vs1) (space->list vs2)))]
    [else universal-space]))

;; Check if program is in version space (strict boolean)
(define (in-space? prog vs)
  (cond
    [(eq? vs empty-space) #f]
    [(eq? vs universal-space) #t]
    [(singleton? vs) (equal? prog (cadr vs))]
    [(list? vs) (and (member prog vs) #t)]
    [else #f]))

;; Update version space based on new example
(define (add-example example vs)
  (match-define (list input output) example)
  (define (fits? p) (matches-example? p input output))
  (cond
    [(eq? vs universal-space) (normalize (filter fits? (generate-candidates)))]
    [(singleton? vs) (if (fits? (cadr vs)) vs empty-space)]
    [(list? vs) (normalize (filter fits? vs))]
    [else vs]))

;; Helper: check if program matches example (numbers only in this chapter,
;; so the input is not consulted)
(define (matches-example? prog input output)
  (and (number? prog) (= prog output)))

;; Generate candidate programs (simplified)
(define (generate-candidates)
  '(0 1 2 3 4 5 (+ 1 1) (* 2 2)))

;; Version space composition
(define (compose-vs vs-list)
  (foldl vs-intersect universal-space vs-list))

(module+ main
  (displayln "=== Version Space Example ===")

  ;; Start with concrete list space (constants 0-5)
  (define vs (list 0 1 2 3 4 5))

  (displayln "Initial version space (constants 0-5):")
  (displayln vs)
  (displayln "")

  (define examples
    '((0 0) (1 2) (2 4) (3 6)))

  (define updated-vs
    (foldl (lambda (ex acc) (add-example ex acc)) vs examples))

  (displayln "After adding examples f(0)=0, f(1)=2, f(2)=4, f(3)=6:")
  (displayln updated-vs)
  (displayln "No constant fits all four points, so the version space is empty.")
  (displayln "")

  (displayln "Size of version space:")
  (displayln (if (eq? updated-vs empty-space) 0 (length updated-vs)))

  (define vs1 '(0 1 2))
  (define vs2 '(1 2 3))

  (displayln "")
  (displayln "Union of {0,1,2} and {1,2,3}:")
  (displayln (vs-union vs1 vs2))

  (displayln "")
  (displayln "Intersection of {0,1,2} and {1,2,3}:")
  (displayln (vs-intersect vs1 vs2))

  (displayln "")
  (displayln "Composing two constraints:")
  (displayln (compose-vs (list vs1 vs2)))

  (displayln "")
  (displayln "Singleton check (1 in {1,2,3}):")
  (displayln (in-space? 1 '(1 2 3)))
  (displayln (in-space? 9 '(1 2 3))))

(module+ test
  (require rackunit)
  (check-equal? (vs-union '(0 1 2) '(1 2 3)) '(0 1 2 3))
  (check-equal? (vs-intersect '(0 1 2) '(1 2 3)) '(1 2))
  (check-true (in-space? 1 '(1 2 3)))
  (check-false (in-space? 9 '(1 2 3)))
  (check-true (in-space? 1 universal-space))
  (check-false (in-space? 1 empty-space))
  (check-equal? (vs-intersect universal-space '(1 2)) '(1 2))
  (check-equal? (vs-union empty-space '(1 2)) '(1 2))
  (check-equal? (add-example '(0 2) '(1 2 3)) '(2))
  ;; Singleton spaces are handled explicitly, not as program lists
  (check-equal? (vs-intersect (singleton 2) '(1 2 3)) (singleton 2))
  (check-equal? (vs-intersect (singleton 9) '(1 2 3)) empty-space)
  (check-equal? (vs-intersect '(1 2 3) (singleton 2)) (singleton 2))
  (check-false (in-space? '(1 2) (singleton 2)))
  (check-true (in-space? 2 (singleton 2)))
  (check-false (in-space? 'singleton (singleton 2)))
  (check-equal? (vs-union (singleton 2) '(1 3)) '(2 1 3))
  (check-equal? (add-example '(0 2) (singleton 2)) (singleton 2))
  (check-equal? (add-example '(0 9) (singleton 2)) empty-space)
  ;; Filtering everything away yields the canonical empty space
  (check-equal? (add-example '(0 9) '(1 2 3)) empty-space)
  (check-equal? (vs-intersect '(1) '(2)) empty-space))
