#lang racket

;;; Why Deep Learning Alone is Insufficient
;;; A tiny perceptron trained on OR and XOR shows interpolation vs
;;; compositional failure.

(require "../utils/math.rkt")

(provide dot
         perceptron
         train-perceptron
         linear-data
         xor-data
         accuracy
         show-preds)

(define (perceptron xs ws)
  (if (> (dot xs ws) 0) 1 0))

(define (train-perceptron dataset weights0 epochs)
  (let loop ([ws weights0] [epochs epochs])
    (if (zero? epochs)
        ws
        (let loop2 ([ws ws] [data dataset])
          (if (null? data)
              (loop ws (- epochs 1))
              (let* ([item (car data)]
                     [xs (cons 1 (car item))]
                     [y (cadr item)]
                     [pred (perceptron xs ws)]
                     [err (- y pred)]
                     [ws* (map (lambda (w x) (+ w (* err x))) ws xs)])
                (loop2 ws* (cdr data))))))))

(define linear-data
  '(((0 0) 0) ((0 1) 1) ((1 0) 1) ((1 1) 1)))

(define xor-data
  '(((0 0) 0) ((0 1) 1) ((1 0) 1) ((1 1) 0)))

(define (accuracy ws data)
  (/ (count (lambda (item) (= (perceptron (cons 1 (car item)) ws) (cadr item))) data)
     (length data)))

(define (show-preds ws data)
  (for ([item data])
    (displayln (format "  Input ~a -> predict ~a, true ~a"
                       (car item)
                       (perceptron (cons 1 (car item)) ws)
                       (cadr item)))))

(module+ main
  (displayln "=== Part 1: Linear function (OR-like) ===")
  (define ws-linear (train-perceptron linear-data '(0 0 0) 20))
  (displayln (format "Learned weights: ~a ~a ~a"
                     (exact->inexact (car ws-linear))
                     (exact->inexact (cadr ws-linear))
                     (exact->inexact (caddr ws-linear))))
  (displayln (format "Training accuracy: ~a" (accuracy ws-linear linear-data)))
  (show-preds ws-linear linear-data)

  (newline)
  (displayln "=== Part 2: Extrapolation beyond training data ===")
  ;; AND-like data: train on all points where the rule says 0; the only
  ;; positive case (1 1) is held out. Trained this way the perceptron
  ;; never moves its weights off zero and predicts 0 for (1 1): it has
  ;; no mechanism to infer the unseen positive case.
  (define train-subset '(((0 0) 0) ((0 1) 0) ((1 0) 0)))
  (define ws-sub (train-perceptron train-subset '(0 0 0) 20))
  (displayln "Train on (0,0),(0,1),(1,0) of AND, test on held-out (1,1)=1:")
  (displayln (format "Learned weights: ~a" ws-sub))
  (define pred-held (perceptron (cons 1 '(1 1)) ws-sub))
  (show-preds ws-sub '(((1 1) 1)))
  (displayln (format "Held-out prediction ~a vs true 1 -> ~a"
                     pred-held
                     (if (= pred-held 1) "OK" "FAIL (never saw a positive, cannot extrapolate)")))
  (displayln "Every training point was negative, so no update ever fired;")
  (displayln "the model has no way to know any input is positive.")

  (newline)
  (displayln "=== Part 3: XOR is not linearly separable ===")
  (define ws-xor (train-perceptron xor-data '(0 0 0) 50))
  (displayln (format "XOR accuracy after 50 epochs: ~a (best possible 0.5)" (accuracy ws-xor xor-data)))
  (show-preds ws-xor xor-data)
  (displayln "A single perceptron cannot represent XOR. Deeper nets memorize")
  (displayln "but do not learn the parity rule."))

(module+ test
  (require rackunit)
  (check-equal? (accuracy (train-perceptron linear-data '(0 0 0) 20) linear-data) 1)
  (check-equal? (accuracy (train-perceptron xor-data '(0 0 0) 50) xor-data) 1/2)
  (check-equal? (dot '(1 2) '(3 4)) 11)
  ;; Held-out AND case: never-seen positive is predicted negative
  (check-equal? (perceptron (cons 1 '(1 1))
                            (train-perceptron '(((0 0) 0) ((0 1) 0) ((1 0) 0)) '(0 0 0) 20))
                0))
