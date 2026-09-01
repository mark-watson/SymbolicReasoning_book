#lang racket

;;; Tiny ARC-Style Task: 1-D grids, hidden rule is reverse

(provide t-identity t-reverse t-sort t-sort-desc t-inc-each t-double-each
         dsl train test-input test-output consistent-with-train? solve-arc)

(define (t-identity xs) xs)
(define (t-reverse xs) (reverse xs))
(define (t-sort xs) (sort xs <))
(define (t-sort-desc xs) (sort xs >))
(define (t-inc-each xs) (map (lambda (x) (+ x 1)) xs))
(define (t-double-each xs) (map (lambda (x) (* 2 x)) xs))

(define dsl
  (list (cons 'identity t-identity) (cons 'reverse t-reverse)
        (cons 'sort t-sort) (cons 'sort-desc t-sort-desc)
        (cons 'inc-each t-inc-each) (cons 'double t-double-each)))

(define train (list (cons '(1 4 2 3) '(3 2 4 1)) (cons '(2 3 4 1) '(1 4 3 2))))
(define test-input '(5 1 3 2))
(define test-output '(2 3 1 5))

(define (consistent-with-train? fn)
  (andmap (lambda (pair) (equal? (fn (car pair)) (cdr pair))) train))

(define (solve-arc train-pairs)
  ;; train-pairs param allows testing with different sets
  (filter (lambda (entry) (andmap (lambda (pair) (equal? ((cdr entry) (car pair)) (cdr pair))) train-pairs)) dsl))

(module+ main
  (define matches (solve-arc train))
  (displayln "=== Tiny ARC-Style Task ===")
  (displayln (format "Train pairs: ~a" train))
  (displayln (format "Consistent transformations: ~a" (map car matches)))
  (for ([m matches])
    (displayln (format "  ~a predicts ~a on ~a (expected ~a) -> ~a"
                       (car m) ((cdr m) test-input) test-input test-output
                       (if (equal? ((cdr m) test-input) test-output) "CORRECT" "WRONG"))))
  (displayln "")
  (displayln "Only 'reverse fits both training pairs. Adding more primitives")
  (displayln "would need more examples to stay uniquely identifiable."))

(module+ test
  (require rackunit)
  (check-equal? (map car (solve-arc train)) '(reverse))
  (check-equal? (t-reverse test-input) test-output))
