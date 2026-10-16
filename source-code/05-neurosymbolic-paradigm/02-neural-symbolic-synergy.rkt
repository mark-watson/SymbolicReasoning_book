#lang racket

;;; The Synergy of Neural Networks and Symbolic Search
;;; Mock MNIST Addition: perception via nearest neighbor over 3x3 patterns,
;;; reasoning via exact integer addition.

(require "../utils/math.rkt")

(provide digit-alphabet
         hamming
         recognize-digit
         neurosymbolic-add
         pure-neural-baseline)

;; 3x3 binary patterns. 0 and 6 differ in one pixel: 6 drops the
;; bottom-middle pixel of 0.
(define digit-alphabet
  '((0 . (1 1 1 1 0 1 1 1 1))
    (1 . (0 1 0 0 1 0 0 1 0))
    (2 . (1 1 0 0 1 0 0 1 1))
    (3 . (1 1 0 0 1 1 0 1 1))
    (4 . (1 0 1 1 1 1 0 0 1))
    (5 . (1 1 1 0 1 1 1 1 0))
    (6 . (1 1 1 1 0 1 1 0 1))
    (7 . (1 1 1 0 0 1 0 1 0))
    (8 . (1 1 1 1 1 1 1 1 1))
    (9 . (1 1 1 1 1 1 0 1 1))))

(define (recognize-digit pattern)
  (car (argmin (lambda (pair) (hamming pattern (cdr pair))) digit-alphabet)))

(define train-pairs
  '((2 1 . 1) (3 1 . 2) (3 2 . 1) (4 2 . 2)
    (5 2 . 3) (6 3 . 3) (7 3 . 4) (8 4 . 4)))

(define (pure-neural-baseline d1 d2)
  (define seen (assoc (cons d1 d2) (map (lambda (p) (cons (cdr p) (car p))) train-pairs)))
  (if seen (cdr seen) '?))

(define (neurosymbolic-add pattern1 pattern2)
  (+ (recognize-digit pattern1) (recognize-digit pattern2)))

(module+ main
  (define p3 (cdr (assoc 3 digit-alphabet)))
  (define p5 (cdr (assoc 5 digit-alphabet)))

  (displayln "=== Pure neural baseline ===")
  (displayln (format "Train pairs (sum . (d1 . d2)): ~a" train-pairs))
  (displayln (format "Trained 2+3 -> ~a" (pure-neural-baseline 2 3)))
  (displayln (format "Unseen 3+5 -> ~a" (pure-neural-baseline 3 5)))
  (displayln "Memorizes a finite table; 3+5 was never seen, so it fails.")

  (newline)
  (displayln "=== Neurosymbolic pipeline ===")
  (displayln (format "Recognize 3 -> ~a" (recognize-digit p3)))
  (displayln (format "Recognize 5 -> ~a" (recognize-digit p5)))
  (displayln (format "0 vs 6 distinct: hamming ~a" (hamming (cdr (assoc 0 digit-alphabet)) (cdr (assoc 6 digit-alphabet)))))
  (displayln (format "3 + 5 -> ~a" (neurosymbolic-add p3 p5)))
  (displayln "Symbolic + works for any pair the perception layer recognizes."))

(module+ test
  (require rackunit)
  (check-equal? (recognize-digit (cdr (assoc 3 digit-alphabet))) 3)
  (check-equal? (recognize-digit (cdr (assoc 5 digit-alphabet))) 5)
  (check-not-equal? (cdr (assoc 0 digit-alphabet)) (cdr (assoc 6 digit-alphabet)))
  (check-equal? (hamming '(0 1 0) '(0 1 0)) 0)
  (check-equal? (pure-neural-baseline 2 3) 5)
  (check-equal? (pure-neural-baseline 3 5) '?)
  ;; every memorized row is a correct sum: (sum d1 . d2)
  (for ([row train-pairs])
    (check-equal? (car row) (+ (cadr row) (cddr row)))))
