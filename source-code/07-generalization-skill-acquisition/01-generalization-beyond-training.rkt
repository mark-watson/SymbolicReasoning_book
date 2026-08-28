#lang racket

;;; Generalizing Beyond the Training Distribution
;;;
;;; This example demonstrates systematic and compositional generalization
;;; using a simple modular arithmetic task.  A synthesizer learns from a
;;; few examples how to compose primitive operations (+1, -1, mod 4)
;;; into programs.  The key point is that once the right composition is
;;; learned, it generalizes to *all* inputs, not just the training set.
;;;
;;; We compare two approaches:
;;;   1. Nearest-neighbor memorization (fails to generalize)
;;;   2. Enumerative synthesis over a grammar (generalizes compositionally)

;; ---------- grammar and evaluator ----------
;; Expressions over a single integer variable x, with constants 0,1,2,3
;; and operations inc, dec, mod4, add, and mul.
(define (eval-expr e x)
  (match e
    ['x x]
    [(? integer? n) n]
    [`(inc ,a) (+ 1 (eval-expr a x))]
    [`(dec ,a) (- (eval-expr a x) 1)]
    [`(mod4 ,a) (modulo (eval-expr a x) 4)]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(- ,a ,b) (- (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [_ (error 'eval-expr "bad expr: ~a" e)]))

;; Generate expressions in a structured, depth-limited way.  To keep the
;; enumeration tractable we combine a shallow "leaf" set with a small
;; number of carefully built binary expansions.
(define (gen-exprs depth)
  (define leaves '(x 0 1 2 3))
  (define unary (append (map (lambda (a) `(inc ,a)) leaves)
                        (map (lambda (a) `(dec ,a)) leaves)
                        (map (lambda (a) `(mod4 ,a)) leaves)))
  ;; Only pair up leaves for binary ops, and add a couple of useful
  ;; compositions that are common in small programs.
  (define binary
    (append
     ;; combine leaves with leaves
     (for*/list ((a leaves) (b leaves)) `(+ ,a ,b))
     (for*/list ((a leaves) (b leaves)) `(- ,a ,b))
     (for*/list ((a leaves) (b leaves)) `(* ,a ,b))
     ;; combine unary results with leaves
     (for*/list ((u unary) (b leaves)) `(+ ,u ,b))
     (for*/list ((u unary) (b leaves)) `(* ,u ,b))
     ;; a couple of higher-depth shapes: (mod4 x)+1, (mod4 (x+1)), etc.
     `((mod4 (+ x x)) (mod4 (* x x)) (mod4 (+ x 1)) (mod4 (* x x))
       (+ (mod4 x) 1) (+ 1 (mod4 x)) (* (mod4 x) 2) (* 2 (mod4 x)))))
  (append leaves unary binary))

;; ---------- constraint checking ----------
(define (satisfies? prog examples)
  (andmap (lambda (ex)
            (= (eval-expr prog (car ex)) (cdr ex)))
          examples))

(define (synthesize examples depth)
  (findf (lambda (e) (satisfies? e examples))
         (gen-exprs depth)))

;; ---------- task ----------
;; The hidden function: f(x) = (x + 1) mod 4  -- a cyclic increment
(define (hidden-f x) (modulo (+ x 1) 4))

;; Training examples only cover x = 0..3
(define train-examples '((0 . 1) (1 . 2) (2 . 3) (3 . 0)))

;; Nearest-neighbor baseline (memorization)
(define (nn-predict x examples)
  (let ((best (argmin (lambda (ex) (abs (- x (car ex)))) examples)))
    (cdr best)))

;; Synthesizer
(define prog (synthesize train-examples 3))

(displayln "=== Generalizing Beyond Training Distribution ===")
(displayln (format "Training examples (x . f(x)): ~a" train-examples))
(displayln (format "Nearest-neighbor prediction on unseen x=4: ~a"
                   (nn-predict 4 train-examples)))
(displayln (format "Synthesized program: ~a" prog))
(displayln (format "Synthesized program on unseen inputs: ~a"
                   (map (lambda (x) (eval-expr prog x)) '(4 5 6 7 8))))
(displayln (format "Hidden function on unseen inputs:      ~a"
                   (map hidden-f '(4 5 6 7 8))))
