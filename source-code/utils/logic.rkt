#lang racket

;;; Soft logic: product t-norm, Reichenbach implication.
;;; Used by differentiable-reasoning, LTN, LNN, NeurASP

(provide t-and
         t-and-list
         t-not
         t-impl)

(define (t-and x y) (* x y))

(define (t-and-list xs) (if (null? xs) 1.0 (apply * xs)))

(define (t-not x) (- 1.0 x))

(define (t-impl x y) (+ 1.0 (- x) (* x y)))
