#lang racket

;;; Test-Time Adaptation and Reasoning
;;;
;;; This example demonstrates synthesizing a program on-the-fly for a
;;; specific input context (online synthesis).  Instead of learning a
;;; global model offline, we encounter a new input at test time and
;;; immediately synthesize a program that explains it.
;;;
;;; Scenario: we receive a stream of pairs (x . y) and must infer the
;;; hidden linear function y = a*x + b.  The synthesizer is triggered
;;; after each new pair, so it adapts online.

;; ---------- tiny synthesizer for f(x) = a*x + b ----------
;; We search over small integer constants a and b.
(define domain '(0 1 2 3 -1 -2 -3))

(define (f a b x) (+ (* a x) b))

(define (synthesize-on-the-fly examples)
  (for*/first ((a domain)
               (b domain)
               #:when (andmap (lambda (ex)
                                (= (f a b (car ex)) (cdr ex)))
                              examples))
    (list a b)))

;; ---------- online adaptation loop ----------
(define (online-synthesis stream)
  (let loop ((examples '()) (rest stream) (step 1))
    (if (null? rest)
        (begin
          (displayln (format "Final model after ~a examples: ~a"
                             (length examples) examples))
          examples)
        (let* ((pair (car rest))
               (examples* (append examples (list pair)))
               (model (synthesize-on-the-fly examples*)))
          (displayln (format "Step ~a: seen ~a, synthesized f(x) = ~a*x + ~a"
                             step pair (first model) (second model)))
          (loop examples* (cdr rest) (+ step 1))))))

;; ---------- run ----------
(displayln "=== Test-Time Adaptation ===")
(define stream '((0 . 1) (1 . 3) (2 . 5)))
(online-synthesis stream)

(newline)
(displayln "Interpretation:")
(displayln "  Each new observation triggers a new synthesis round.  Because")
(displayln "  the system produces a symbolic model (a and b), it can be")
(displayln "  applied immediately to unseen inputs without retraining.")
(displayln (format "  Final model predicts f(4) = ~a"
                   (let ((model (synthesize-on-the-fly '((0 . 1) (1 . 3) (2 . 5)))))
                     (f (first model) (second model) 4))))
