#lang racket

;;; Version Space Algebras
;;; Compact representation of consistent hypothesis spaces

(provide (all-defined-out))

;; A version space is the set of all hypotheses consistent with examples
;; We represent it as a union of simpler spaces

;; Basic version space operations

;; The universal space (all possible programs)
(define universal-space 'universal)

;; The empty space (no programs)
(define empty-space 'empty)

;; Create a singleton space
(define (singleton prog) (list 'singleton prog))

;; Intersection: programs in both spaces
(define (vs-intersect vs1 vs2)
  (cond
    ((eq? vs1 empty-space) empty-space)
    ((eq? vs2 empty-space) empty-space)
    ((eq? vs1 universal-space) vs2)
    ((eq? vs2 universal-space) vs1)
    ((and (pair? vs1) (pair? vs2))
     ;; Simplified intersection for demonstration
     (filter (lambda (p) (member p vs2)) vs1))
    (else empty-space)))

;; Union: programs in either space
(define (vs-union vs1 vs2)
  (cond
    ((eq? vs1 empty-space) vs2)
    ((eq? vs2 empty-space) vs1)
    ((eq? vs1 universal-space) universal-space)
    ((eq? vs2 universal-space) universal-space)
    ((and (list? vs1) (list? vs2))
     ;; Simplified union for demonstration  
     (remove-duplicates (append vs1 vs2)))
    (else universal-space)))

;; Check if program is in version space
(define (in-space? prog vs)
  (cond
    ((eq? vs empty-space) #f)
    ((eq? vs universal-space) #t)
    ((list? vs) (member prog vs))
    (else #f)))

;; Update version space based on new example
(define (add-example example vs)
  (let ((input (car example))
        (output (cadr example)))
    (cond
      ((eq? vs universal-space)
       ;; Initial version space is just matching programs
       (filter (lambda (p) (matches-example? p input output)) 
               (generate-candidates)))
      ((list? vs)
       ;; Filter existing space
       (filter (lambda (p) (matches-example? p input output)) vs))
      (else vs))))

;; Helper: check if program matches example
(define (matches-example? prog input output)
  ;; Simplified: just check if prog(input) = output
  ;; In practice, this would evaluate the program
  (and (number? prog) (= prog output)))

;; Generate candidate programs (simplified)
(define (generate-candidates)
  '(0 1 2 3 4 5 (+ 1 1) (* 2 2)))

;; Version space composition
(define (compose-vs vs-list)
  (foldl vs-intersect universal-space vs-list))

;; Example: Learning a linear function
(displayln "=== Version Space Example ===")

 ;; Start with universal space
(define vs (list 0 1 2 3 4 5))  ; Simplified: space of constants 0-5

(displayln "Initial version space (constants 0-5):")
(displayln vs)
(displayln "")

;; Add examples: f(x) = 2x
(define examples
  '((0 0)      ; f(0) = 0
    (1 2)      ; f(1) = 2  
    (2 4)      ; f(2) = 4
    (3 6)))    ; f(3) = 6

;; Update version space with each example
(define updated-vs 
  (foldl (lambda (ex acc) (add-example ex acc)) 
         vs 
         examples))

(displayln "After adding examples f(0)=0, f(1)=2, f(2)=4, f(3)=6:")
(displayln updated-vs)
(displayln "")

;; Check size of version space
(displayln "Size of version space:")
(displayln (length updated-vs))

;; Demonstrate intersection and union
(define vs1 '(0 1 2))
(define vs2 '(1 2 3))

(displayln "")
(displayln "Union of {0,1,2} and {1,2,3}:")
(displayln (vs-union vs1 vs2))

(displayln "")
(displayln "Intersection of {0,1,2} and {1,2,3}:")
(displayln (vs-intersect vs1 vs2))

;; Composing multiple constraints
(displayln "")
(displayln "Composing two constraints:")
(define composed (compose-vs (list vs1 vs2)))
(displayln composed)
