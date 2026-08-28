#lang racket

;;; Version Space Algebra for Program Synthesis
;;; Maintains compact representation of consistent hypotheses

(provide (all-defined-out))

;; Version space representation
(struct vs (desc candidates) #:transparent)

;; Create a version space from candidates
(define (make-version-space desc candidates)
  (vs desc candidates))

;; Update version space with new example
(define (vs-update example old-vs)
  (let ((input (car example))
        (output (cadr example))
        (candidates (vs-candidates old-vs)))
    (let ((filtered
           (filter (lambda (c) (predict-for-example c input output))
                   candidates)))
      (vs (vs-desc old-vs) filtered))))

;; Check if candidate predicts the example
(define (predict-for-example candidate input output)
  (equal? (apply-operation candidate input) output))

;; Helper function
(define (string-reverse s)
  (list->string (reverse (string->list s))))

;; Apply a string operation
(define (apply-operation op input)
  (case op
    ((identity) input)
    ((reverse) (string-reverse input))
    ((to-upper) (string-upcase input))
    ((to-lower) (string-downcase input))
    (else input)))

;; Combine version spaces
(define (vs-union vs1 vs2)
  (vs (vs-desc vs1) 
      (remove-duplicates 
       (append (vs-candidates vs1) (vs-candidates vs2)))))

(define (vs-intersect vs1 vs2)
  (vs (vs-desc vs1)
      (filter (lambda (c) (member c (vs-candidates vs2)))
              (vs-candidates vs1))))

;; Example usage
(displayln "=== Version Space Example ===")

;; Define hypothesis space
(define op-space (make-version-space "String operations" 
                                  '(identity reverse to-upper to-lower)))

(display "Initial candidates: ")
(displayln (length (vs-candidates op-space)))

;; Example 1: reverse behavior
(define ex1 '("hello" "olleh"))
(define vs-after-ex1 (vs-update ex1 op-space))

(display "After updating with '\"hello\" -> \"olleh\"': ")
(displayln (length (vs-candidates vs-after-ex1)))
(display "Candidates: ")
(displayln (vs-candidates vs-after-ex1))

;; Example 2: case conversion
(define ex2 '("HELLO" "hello"))
(define vs-after-ex2 (vs-update ex2 op-space))

(display "After updating with '\"HELLO\" -> \"hello\"': ")
(displayln (length (vs-candidates vs-after-ex2)))
(display "Candidates: ")
(displayln (vs-candidates vs-after-ex2))

;; Composing spaces
(define combined (vs-intersect vs-after-ex1 vs-after-ex2))
(display "Intersection of two examples: ")
(displayln (vs-candidates combined))
