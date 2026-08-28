#lang racket

;;; The Synergy of Neural Networks and Symbolic Search
;;;
;;; We study the classic "MNIST Addition" task: two digits are drawn as
;;; small bitmaps, and the system must predict their sum.
;;; A purely neural baseline treats the task as end-to-end regression
;;; and fails badly on unseen combinations.
;;; A neurosymbolic pipeline separates perception and reasoning:
;;;   1. A neural component recognizes each digit independently.
;;;   2. A symbolic component applies the arithmetic rule (integer addition).
;;; The symbolic layer cannot hallucinate: 3+5 is always 8.
;;;
;;; To keep the example dependency-free, the "neural" component is a
;;; tiny nearest-neighbor classifier over a hard-coded alphabet of
;;; 3x3 digit bitmaps. The point is the architecture, not the learning
;;; algorithm.

;; ---------- mock perceptual alphabet ----------
;; Each digit is a 3x3 binary pattern represented as a list of 9 bits.
(define digit-alphabet
  '((0 . (1 1 1 1 0 1 1 1 1))
    (1 . (0 1 0 0 1 0 0 1 0))
    (2 . (1 1 0 0 1 0 0 1 1))
    (3 . (1 1 0 0 1 1 0 1 1))
    (4 . (1 0 1 1 1 1 0 0 1))
    (5 . (1 1 1 0 1 1 1 1 0))
    (6 . (1 1 1 1 0 1 1 1 1))
    (7 . (1 1 1 0 0 1 0 1 0))
    (8 . (1 1 1 1 1 1 1 1 1))
    (9 . (1 1 1 1 1 1 0 1 1))))

;; Hamming distance between two patterns
(define (hamming xs ys)
  (length (filter (lambda (p) (not (equal? (car p) (cdr p))))
                  (map cons xs ys))))

;; Nearest neighbor classifier: return the digit whose template is closest
(define (recognize-digit pattern)
  (let ((best (argmin (lambda (pair) (hamming pattern (cdr pair)))
                      digit-alphabet)))
    (car best)))

;; ---------- Part 1: pure neural end-to-end baseline ----------
;; The baseline sees no structure; it memorizes input pairs to sum.
;; This is a stand-in for a large network trained on a finite dataset.
(define train-pairs
  '((1 . (1 . 1)) (2 . (1 . 2)) (3 . (2 . 1)) (4 . (2 . 2))
    (5 . (2 . 3)) (6 . (3 . 3)) (7 . (3 . 4)) (8 . (4 . 4))))

(define (pure-neural-baseline d1 d2)
  (let ((seen (assoc (cons d1 d2)
                     (map (lambda (p) (cons (cdr p) (car p)))
                          train-pairs))))
    (if seen (cdr seen) '?)))

;; ---------- Part 2: neurosymbolic pipeline ----------
(define (neurosymbolic-add pattern1 pattern2)
  (+ (recognize-digit pattern1)
     (recognize-digit pattern2)))

;; Test cases: patterns of 3 and 5
(define p3 (cdr (assoc 3 digit-alphabet)))
(define p5 (cdr (assoc 5 digit-alphabet)))

(displayln "=== Pure neural baseline ===")
(displayln (format "Train pairs (sum . (d1 . d2)): ~a" train-pairs))
(displayln (format "Trained 2+3 -> ~a" (pure-neural-baseline 2 3)))
(displayln (format "Unseen 3+5 -> ~a" (pure-neural-baseline 3 5)))
(displayln "The baseline memorizes a finite lookup table. 3+5 was never")
(displayln "seen, and the model has no arithmetic rule to fall back on.")

(newline)
(displayln "=== Neurosymbolic pipeline ===")
(displayln (format "Recognize 3 -> ~a" (recognize-digit p3)))
(displayln (format "Recognize 5 -> ~a" (recognize-digit p5)))
(displayln (format "3 + 5 -> ~a" (neurosymbolic-add p3 p5)))
(displayln "The symbolic layer applies +, so any unseen pair the percep-")
(displayln "tion layer recognizes is summed correctly.")
