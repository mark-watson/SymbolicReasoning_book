#lang racket

;;; Data-Efficient Learning: 4 points plus physics grammar suffice

(provide eval-expr gen-exprs fit-error size measurements)

(require racket/match)

(define (eval-expr e t)
  (match e
    ['t t]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a t) (eval-expr b t))]
    [`(- ,a ,b) (- (eval-expr a t) (eval-expr b t))]
    [`(* ,a ,b) (* (eval-expr a t) (eval-expr b t))]
    [`(/ ,a ,b) (let ([d (eval-expr b t)]) (if (zero? d) +inf.0 (/ (eval-expr a t) d)))]
    [`(sq ,a) (let ([v (eval-expr a t)]) (* v v))]
    [_ (raise-argument-error 'eval-expr "physics expr" e)]))

(define constants '(1 2 3 4 5 1/2))
(define leaves (cons 't constants))

(define (gen-exprs depth)
  (if (= depth 1) leaves
      (let ([smaller (gen-exprs (- depth 1))])
        (append leaves
                (for/list ([a smaller]) `(sq ,a))
                (for*/list ([a smaller] [b leaves]) `(* ,a ,b))
                (for*/list ([a smaller] [b leaves]) `(+ ,a ,b))
                (for*/list ([a smaller] [b leaves]) `(/ ,a ,b))))))

(define (fit-error e data)
  (apply + (map (lambda (pair) (let ([d (- (eval-expr e (car pair)) (cdr pair))]) (* d d))) data)))

(define (size e)
  (match e
    [(or 't (? number?)) 1]
    [`(sq ,a) (+ 1 (size a))]
    [`(,(or '+ '- '* '/) ,a ,b) (+ 1 (size a) (size b))]
    [_ 1]))

(define measurements '((1 . 4.95) (2 . 19.6) (3 . 44.0) (4 . 78.5)))

(module+ main
  (displayln "=== Data-Efficient Learning ===")
  (displayln (format "Training set has only ~a examples." (length measurements)))
  (define candidates (gen-exprs 3))
  (define ranked (sort (map (lambda (e) (list e (fit-error e measurements) (size e))) candidates)
                       < #:key second))
  (displayln (format "Number of hypotheses enumerated: ~a" (length ranked)))
  (newline)
  (displayln "Top 5 by fit (with size):")
  (for ([p (take ranked 5)])
    (displayln (format "  ~a  err=~a size=~a" (first p) (exact->inexact (second p)) (third p))))
  (newline)
  (displayln "Best is 5*t^2 = 5*(sq t), vs truth 4.9*t^2. Coarse constants trade")
  (displayln "precision for form; the grammar's bias toward quadratic-in-t wins."))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(sq t) 3) 9)
  (check-true (< (fit-error '(* (sq t) 5) measurements) (fit-error '(* t 2) measurements))))
