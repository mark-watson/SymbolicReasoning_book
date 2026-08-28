#lang racket

;;; Differentiable Reasoning and Logic
;;;
;;; Hard logic uses crisp truth values (0/1). If we relax Boolean
;;; connectives to the unit interval [0,1], logic becomes smooth and
;;; differentiable. We can then train the "confidence" weights of facts
;;; with gradient descent, treating logical inference as a neural layer.
;;;
;;; This example encodes the classic syllogism
;;;     human(x)  ->  mortal(x)
;;; as a soft rule. Starting from a low confidence in mortal(socrates),
;;; gradient ascent on the satisfaction of the knowledge base drives the
;;; degree of mortal(socrates) toward 1: the network *learns* the
;;; conclusion of the rule rather than being given it.

;; ---------- t-norms for smooth connectives ----------
(define (t-and x y) (* x y))                      ; product t-norm
(define (t-not x)    (- 1 x))                      ; standard negation
;; Reichenbach (product) implication: smooth and differentiable everywhere
(define (t-impl x y) (+ 1 (- x) (* x y)))          ; 1 - x + x*y

;; ---------- satisfaction of the knowledge base ----------
;; KB = (human(socrates) AND (human(socrates) -> mortal(socrates)))
;; Both conjuncts must be simultaneously satisfied.
(define (satisfaction s)
  (let ((hs (hash-ref s 'human-socrates))
        (ms (hash-ref s 'mortal-socrates)))
    (t-and hs
           (t-impl hs ms))))

;; ---------- finite-difference gradient of satisfaction ----------
;; Differentiable relaxation is what makes this gradient meaningful.
(define ((grad k h) s)
  (let ((s+ (hash-update s k (lambda (v) (min 1 (+ v h)))))
        (s- (hash-update s k (lambda (v) (max 0 (- v h))))))
    (/ (- (satisfaction s+) (satisfaction s-))
       (* 2 h))))

;; ---------- training loop ----------
;; Gradient ascent on satisfaction w.r.t. mortal-socrates.
;; human(socrates) stays fixed at 0.9 (a perceptual input, e.g. from a
;; vision system that saw Socrates and classified him as human).
(define (learn steps lr)
  (let loop ((s (hash 'human-socrates 0.9
                      'mortal-socrates 0.2))
             (i 0))
    (if (= i steps)
        s
        (let* ((g      ((grad 'mortal-socrates 1e-4) s))
               (new-ms (max 0 (min 1 (+ (hash-ref s 'mortal-socrates)
                                        (* lr g))))))
          (loop (hash-set s 'mortal-socrates new-ms)
                (+ i 1))))))

;; ---------- demonstrate ----------
(define s0 (hash 'human-socrates 0.9
                 'mortal-socrates 0.2))

(displayln "=== Soft logic before training ===")
(displayln (format "human(socrates)  = ~a  (given by perception)" (hash-ref s0 'human-socrates)))
(displayln (format "mortal(socrates) = ~a  (initial belief)" (hash-ref s0 'mortal-socrates)))
(displayln (format "KB satisfaction  = ~a" (exact->inexact (satisfaction s0))))
(displayln (format "grad(sat, mortal(socrates)) = ~a"
                   (exact->inexact ((grad 'mortal-socrates 1e-4) s0))))

(define s1 (learn 200 0.5))

(newline)
(displayln "=== After training (gradient ascent on satisfaction) ===")
(displayln (format "human(socrates)  = ~a" (hash-ref s1 'human-socrates)))
(displayln (format "mortal(socrates) = ~a"
                   (exact->inexact (hash-ref s1 'mortal-socrates))))
(displayln (format "KB satisfaction  = ~a" (exact->inexact (satisfaction s1))))

(newline)
(displayln "Interpretation:")
(displayln "  The rule human -> mortal and the observation that Socrates")
(displayln "  is human jointly place gradient pressure on belief in")
(displayln "  mortal(socrates). Gradient ascent raises it toward 1.")
(displayln "  This is differentiable inference: deriving a conclusion by")
(displayln "  descending on the violation of a logical knowledge base.")
