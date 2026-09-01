#lang racket

;;; Math helpers shared by CPS, LTN, LNN, NeurASP, dILP, and search demos

(provide dot
         sigmoid
         hamming
         clamp01)

(define (dot xs ys)
  (unless (= (length xs) (length ys))
    (raise-argument-error 'dot "equal-length lists" 0 xs ys))
  (apply + (map * xs ys)))

(define (sigmoid x)
  (/ 1.0 (+ 1.0 (exp (- x)))))

(define (hamming xs ys)
  (length (filter (lambda (p) (not (equal? (car p) (cdr p))))
                  (map cons xs ys))))

(define (clamp01 x) (max 0.0 (min 1.0 x)))
