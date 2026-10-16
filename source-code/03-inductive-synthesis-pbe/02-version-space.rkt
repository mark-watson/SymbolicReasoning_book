#lang racket

;;; Version Space Algebra for Program Synthesis

(require "../utils/string.rkt")

(provide vs
         vs-desc
         vs-candidates
         make-version-space
         vs-update
         predict-for-example
         apply-operation
         vs-union
         vs-intersect)

(struct vs (desc candidates) #:transparent)

(define (make-version-space desc candidates)
  (vs desc candidates))

(define (vs-update example old-vs)
  (match-define (list input output) example)
  (define candidates (vs-candidates old-vs))
  (define filtered
    (filter (lambda (c) (predict-for-example c input output)) candidates))
  (vs (vs-desc old-vs) filtered))

(define (predict-for-example candidate input output)
  (equal? (apply-operation candidate input) output))

(define (apply-operation op input)
  (case op
    [(identity) input]
    [(reverse) (string-reverse input)]
    [(to-upper) (string-upcase input)]
    [(to-lower) (string-downcase input)]
    ;; An unknown name must not silently act as identity, or a typo would
    ;; pass every example where input equals output.
    [else (raise-argument-error 'apply-operation "known operation" op)]))

(define (vs-union vs1 vs2)
  (vs (vs-desc vs1)
      (remove-duplicates (append (vs-candidates vs1) (vs-candidates vs2)))))

(define (vs-intersect vs1 vs2)
  (vs (vs-desc vs1)
      (filter (lambda (c) (member c (vs-candidates vs2)))
              (vs-candidates vs1))))

(module+ main
  (displayln "=== Version Space Example ===")

  (define op-space (make-version-space "String operations"
                                       '(identity reverse to-upper to-lower)))

  (displayln (format "Initial candidates: ~a" (length (vs-candidates op-space))))

  (define ex1 '("hello" "olleh"))
  (define vs-after-ex1 (vs-update ex1 op-space))

  (displayln (format "After 'hello' -> 'olleh': ~a candidates ~a"
                     (length (vs-candidates vs-after-ex1))
                     (vs-candidates vs-after-ex1)))

  (define ex2 '("HELLO" "hello"))
  (define vs-after-ex2 (vs-update ex2 op-space))

  (displayln (format "After 'HELLO' -> 'hello': ~a candidates ~a"
                     (length (vs-candidates vs-after-ex2))
                     (vs-candidates vs-after-ex2)))

  (define combined (vs-intersect vs-after-ex1 vs-after-ex2))
  (displayln (format "Intersection of the two filtered spaces: ~a" (vs-candidates combined)))
  (displayln "No single primitive is both reverse and to-lower.")

  (define sequential (vs-update ex2 vs-after-ex1))
  (displayln (format "Sequential filter (hello->olleh then HELLO->hello): ~a"
                     (vs-candidates sequential))))

(module+ test
  (require rackunit)
  (define op-space (make-version-space "ops" '(identity reverse to-upper to-lower)))
  (check-equal? (length (vs-candidates (vs-update '("hello" "olleh") op-space))) 1)
  (check-equal? (vs-candidates (vs-update '("hello" "olleh") op-space)) '(reverse))
  (check-equal? (vs-candidates (vs-update '("HELLO" "hello") op-space)) '(to-lower))
  (define a (vs-update '("hello" "olleh") op-space))
  (define b (vs-update '("HELLO" "hello") op-space))
  (check-equal? (vs-candidates (vs-intersect a b)) '())
  (check-equal? (length (vs-candidates (vs-union a b))) 2)
  (check-exn exn:fail? (lambda () (apply-operation 'idenity "x"))))
