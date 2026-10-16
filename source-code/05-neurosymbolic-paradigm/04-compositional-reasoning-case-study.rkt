#lang racket

;;; Case Study: Compositional Reasoning: memorization vs synthesis

(provide eval-expr
         gen-exprs
         satisfies?
         enumerate)

(require racket/match
         (only-in "../utils/eval.rkt" ast-size))

(define (eval-expr e x)
  (match e
    ['x x]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [_ (raise-argument-error 'eval-expr "arith expr" e)]))

;; Stably sorted by node count, so the smallest fitting program wins
;; (ties keep generation order: + before *).
(define (gen-exprs depth)
  (define (layer depth)
    (if (= depth 0)
        '(x 0 1)
        (let ([subs (layer (- depth 1))])
          (append '(x 0 1)
                  (for*/list ([a subs] [b subs]) `(+ ,a ,b))
                  (for*/list ([a subs] [b subs]) `(* ,a ,b))))))
  (sort (layer depth) < #:key ast-size #:cache-keys? #t))

(define (satisfies? prog examples)
  (andmap (lambda (ex) (= (eval-expr prog (car ex)) (cdr ex))) examples))

(define (enumerate examples depth)
  (findf (lambda (e) (satisfies? e examples)) (gen-exprs depth)))

(module+ main
  (define example '((3 . 6)))

  (displayln "=== Pure neural baseline ===")
  (displayln (format "Training example: ~a" example))
  (displayln "Pure neural: memorize nearest seen pair. No rule, so x=5 is undefined.")

  (newline)
  (displayln "=== Neurosymbolic synthesizer ===")
  (define prog (enumerate example 2))
  (displayln (format "Input example: ~a" example))
  (displayln (format "Synthesized program (first fit in size order): ~a" prog))
  (displayln (format "Check on unseen inputs: ~a" (map (lambda (x) (eval-expr prog x)) '(0 1 2 3 4 5))))
  (displayln "Program (+ x x) is executable and generalizes compositionally."))

(module+ test
  (require rackunit)
  (check-equal? (enumerate '((3 . 6)) 2) '(+ x x))
  (check-equal? (eval-expr '(+ x x) 5) 10)
  (check-equal? (enumerate '((0 . 0) (1 . 1) (2 . 4)) 2) '(* x x)))
