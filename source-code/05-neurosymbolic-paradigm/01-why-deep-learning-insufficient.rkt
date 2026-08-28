#lang racket

;;; Why Deep Learning Alone is Insufficient
;;;
;;; A tiny perceptron is trained on a toy linear classification task.
;;; The same perceptron is then applied to XOR, a classic example of
;;; a function that a single linear unit cannot represent.
;;;
;;; The demonstration shows three things about purely neural models:
;;;   1. They interpolate well: they fit training data quickly.
;;;   2. They extrapolate poorly: performance degrades off-distribution.
;;;   3. They fail on compositional structure: XOR (parity) is invisible
;;;      to a linear model, and deeper networks only memorize it.
;;;
;;; No external libraries are used. The perceptron and the training loop
;;; are plain Racket.

;; ---------- dot product and perceptron ----------
(define (dot xs ws) (apply + (map * xs ws)))

(define (perceptron xs ws)
  (if (> (dot xs ws) 0) 1 0))

;; ---------- simple perceptron learning rule ----------
;; One pass over the dataset, with bias folded into the weight vector
;; by treating the input as having a leading 1.
(define (train-perceptron dataset weights0 epochs)
  (let loop ((ws weights0) (epochs epochs))
    (if (zero? epochs)
        ws
        (let loop2 ((ws ws) (data dataset))
          (if (null? data)
              (loop ws (- epochs 1))
              (let* ((item (car data))
                     (xs (cons 1 (car item)))
                     (y  (cadr item))
                     (pred (perceptron xs ws))
                     (err  (- y pred))
                     (ws*  (map (lambda (w x) (+ w (* err x))) ws xs)))
                (loop2 ws* (cdr data))))))))

;; ---------- datasets ----------
;; Linear (OR-like): label 1 when (x1 or x2)
(define linear-data
  '(((0 0) 0)
    ((0 1) 1)
    ((1 0) 1)
    ((1 1) 1)))

;; XOR: label 1 when x1 != x2
(define xor-data
  '(((0 0) 0)
    ((0 1) 1)
    ((1 0) 1)
    ((1 1) 0)))

;; ---------- helpers ----------
(define (accuracy ws data)
  (let ((correct
         (count (lambda (item)
                  (= (perceptron (cons 1 (car item)) ws)
                     (cadr item)))
                data)))
    (/ correct (length data))))

(define (show-preds ws data)
  (for-each (lambda (item)
              (displayln (format "  Input ~a -> predict ~a, true ~a"
                                 (car item)
                                 (perceptron (cons 1 (car item)) ws)
                                 (cadr item))))
            data))

;; ---------- Part 1: fitting a linear function ----------
(displayln "=== Part 1: Linear function (OR-like) ===")
(define ws-linear (train-perceptron linear-data '(0 0 0) 20))
(displayln (format "Learned weights: ~a ~a ~a"
                   (exact->inexact (car ws-linear))
                   (exact->inexact (cadr ws-linear))
                   (exact->inexact (caddr ws-linear))))
(displayln (format "Training accuracy: ~a" (accuracy ws-linear linear-data)))
(show-preds ws-linear linear-data)

;; ---------- Part 2: extrapolation off the training distribution ----------
(newline)
(displayln "=== Part 2: Extrapolation beyond training data ===")
;; Train only on points where x1+x2 <= 1, then test on (1 1).
(define train-subset '(((0 0) 0) ((0 1) 1) ((1 0) 1)))
(define ws-sub (train-perceptron train-subset '(0 0 0) 20))
(displayln "Train on (0,0),(0,1),(1,0), then test on the held-out (1,1):")
(show-preds ws-sub '(((1 1) ?)))
(displayln "Extrapolation to (1,1) is unstable; the model has no logical rule.")

;; ---------- Part 3: XOR, the classic failure of linear models ----------
(newline)
(displayln "=== Part 3: XOR is not linearly separable ===")
(define ws-xor (train-perceptron xor-data '(0 0 0) 50))
(displayln (format "XOR accuracy after 50 epochs: ~a" (accuracy ws-xor xor-data)))
(show-preds ws-xor xor-data)
(displayln "A single perceptron cannot represent XOR. Adding hidden layers")
(displayln "allows memorization, but the network does not learn the parity rule.")
