#lang racket

;;; Differentiable Reasoning: soft logic with product t-norm gives a
;;; differentiable loss; gradient ascent on KB satisfaction raises
;;; belief in mortal(socrates) without touching human(socrates).

(require "../utils/logic.rkt")

(provide satisfaction
         grad
         learn)

(define (satisfaction s)
  (let ([hs (hash-ref s 'human-socrates)]
        [ms (hash-ref s 'mortal-socrates)])
    (t-and hs (t-impl hs ms))))

(define ((grad k h) s)
  (define s+ (hash-update s k (lambda (v) (min 1 (+ v h)))))
  (define s- (hash-update s k (lambda (v) (max 0 (- v h)))))
  (/ (- (satisfaction s+) (satisfaction s-)) (* 2 h)))

;; Gradient ascent on satisfaction w.r.t. mortal-socrates; human stays fixed.
;; This is direct ascent on belief, not backprop through a network.
(define (learn steps lr)
  (let loop ([s (hash 'human-socrates 0.9 'mortal-socrates 0.2)] [i 0])
    (if (= i steps) s
        (let* ([g ((grad 'mortal-socrates 1e-4) s)]
               [new-ms (max 0 (min 1 (+ (hash-ref s 'mortal-socrates) (* lr g))))])
          (loop (hash-set s 'mortal-socrates new-ms) (+ i 1))))))

(module+ main
  (define s0 (hash 'human-socrates 0.9 'mortal-socrates 0.2))

  (displayln "=== Soft logic before training ===")
  (displayln (format "human(socrates)  = ~a (perception)" (hash-ref s0 'human-socrates)))
  (displayln (format "mortal(socrates) = ~a (initial belief)" (hash-ref s0 'mortal-socrates)))
  (displayln (format "KB satisfaction  = ~a" (exact->inexact (satisfaction s0))))
  (displayln (format "grad(sat, mortal) = ~a" (exact->inexact ((grad 'mortal-socrates 1e-4) s0))))

  (define s1 (learn 200 0.5))

  (newline)
  (displayln "=== After training (gradient ascent on satisfaction) ===")
  (displayln (format "human(socrates)  = ~a" (hash-ref s1 'human-socrates)))
  (displayln (format "mortal(socrates) = ~a" (exact->inexact (hash-ref s1 'mortal-socrates))))
  (displayln (format "KB satisfaction  = ~a" (exact->inexact (satisfaction s1))))

  (newline)
  (displayln "The rule human->mortal plus human(socrates)=0.9 puts gradient")
  (displayln "pressure on mortal(socrates), raising it toward 1."))

(module+ test
  (require rackunit)
  (check-true (> (satisfaction (learn 200 0.5)) (satisfaction (hash 'human-socrates 0.9 'mortal-socrates 0.2))))
  (check-= (hash-ref (learn 200 0.5) 'mortal-socrates) 1.0 0.01))
