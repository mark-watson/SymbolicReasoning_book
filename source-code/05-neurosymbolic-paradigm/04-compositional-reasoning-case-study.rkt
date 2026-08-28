#lang racket

;;; Case Study: Compositional Reasoning
;;;
;;; A purely neural model is asked to produce a short program from one
;;; example. Like a large pattern matcher, it memorizes the training
;;; instance and fails on compositional generalization.
;;; A neurosymbolic synthesizer separates the problem:
;;;   1. A perception/deduction component extracts constraints.
;;;   2. A symbolic enumerative synthesizer searches over a grammar,
;;;      verifying candidates with the constraint checker.
;;; The result generalizes to any input because the discovered program
;;; is symbolic and executable.

;; ---------- grammar and evaluator ----------
;; Grammar: x, 0, 1, (+ e e), (* e e)
(define (eval-expr e x)
  (match e
    ['x x]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]))

(define (gen-exprs depth)
  (if (= depth 0)
      '(x 0 1)
      (let ((subs (gen-exprs (- depth 1))))
        (append '(x 0 1)
                (for*/list ((a subs) (b subs)) `(+ ,a ,b))
                (for*/list ((a subs) (b subs)) `(* ,a ,b))))))

;; ---------- constraint checker ----------
(define (satisfies? prog examples)
  (andmap (lambda (ex)
            (= (eval-expr prog (car ex)) (cdr ex)))
          examples))

;; ---------- enumerative synthesizer ----------
(define (enumerate examples depth)
  (findf (lambda (e) (satisfies? e examples))
         (gen-exprs depth)))

;; ---------- Part 1: pure neural baseline ----------
;; The baseline maps the single example it has seen directly to the answer.
(define (pure-neural-synthesize examples)
  (displayln "Pure neural baseline: memorize nearest seen pair.")
  (list 'memorize examples))

;; ---------- run the study ----------
(define example '((3 . 6)))

(displayln "=== Pure neural baseline ===")
(displayln (format "Training example: ~a" example))
(pure-neural-synthesize example)
(displayln "Unseen input x=5: no rule available, prediction is undefined.")

(newline)
(displayln "=== Neurosymbolic synthesizer ===")
(define prog (enumerate example 2))
(displayln (format "Input example: ~a" example))
(displayln (format "Synthesized program: ~a" prog))
(displayln (format "Check on unseen inputs: ~a"
                   (map (lambda (x) (eval-expr prog x))
                        '(0 1 2 3 4 5))))
(displayln "The symbolic program (+ x x) is executable and generalizes")
(displayln "compositionally: it is not limited to the training example.")
