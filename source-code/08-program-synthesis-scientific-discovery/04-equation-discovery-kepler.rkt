#lang racket

;;; Kepler's Third Law: T^2 proportional to a^3 (normalized k=1, 6 noisy points)

(provide eval-law law-size gen-laws fit-error score observations best-law)

(require racket/match)

(define (eval-law e a)
  (match e
    ['a a]
    [(? number? n) n]
    [`(+ ,x ,y) (+ (eval-law x a) (eval-law y a))]
    [`(* ,x ,y) (* (eval-law x a) (eval-law y a))]
    [`(pow2 ,x) (let ([v (eval-law x a)]) (* v v))]
    [`(pow3 ,x) (let ([v (eval-law x a)]) (* v v v))]
    [_ (raise-argument-error 'eval-law "kepler expr" e)]))

(define (law-size e)
  (match e
    [(or 'a (? number?)) 1]
    [`(,(or 'pow2 'pow3) ,x) (+ 1 (law-size x))]
    [`(,(or '+ '*) ,x ,y) (+ 1 (law-size x) (law-size y))]
    [_ 1]))

(define (gen-laws)
  (define atoms '(a 1 2 3))
  (define unary (append (map (lambda (x) `(pow2 ,x)) atoms)
                        (map (lambda (x) `(pow3 ,x)) atoms)))
  (remove-duplicates
   (append atoms unary
           (for*/list ([x atoms] [y (append atoms unary)]) `(* ,x ,y))
           (for*/list ([x atoms] [y unary]) `(+ ,x ,y)))
   equal?))

(define observations
  '((1.0  .  1.02) (1.5  .  3.40) (2.0  .  7.95)
    (2.5  . 15.70) (3.0  . 27.10) (3.5  . 42.80)))

(define (fit-error law)
  (apply + (map (lambda (obs) (let ([d (- (eval-law law (car obs)) (cdr obs))]) (* d d))) observations)))

(define (score law) (+ (fit-error law) (* 0.1 (law-size law))))

(define (best-law) (first (first (sort (map (lambda (l) (list l (fit-error l) (law-size l) (score l))) (gen-laws))
                                        < #:key fourth))))

(module+ main
  (displayln "=== Equation Discovery: Kepler's Third Law ===")
  (displayln (format "Observations (a . T^2): ~a pairs (noisy, k=1)" (length observations)))
  (newline)
  (define ranked (sort (map (lambda (l) (list l (fit-error l) (law-size l) (score l))) (gen-laws))
                       < #:key fourth))
  (displayln "Top candidates (law, fit error, size, score):")
  (for ([r (take ranked 6)])
    (displayln (format "  T^2 = ~a   err=~a size=~a score=~a"
                       (first r) (exact->inexact (second r)) (third r) (exact->inexact (fourth r)))))
  (newline)
  (define best (first (first ranked)))
  (displayln (format "Discovered law: T^2 = ~a" best))
  (displayln "This is Kepler's third law: T^2 scales with a^3.")
  (newline)
  (displayln "Verification on held-out a=4.0,4.5 (noise-free truth):")
  (define held-out '((4.0 . 64.0) (4.5 . 91.125)))
  (for ([obs held-out])
    (displayln (format "  a=~a predicted T^2=~a actual ~a"
                       (car obs) (exact->inexact (eval-law best (car obs))) (cdr obs)))))

(module+ test
  (require rackunit)
  (check-equal? (eval-law '(pow3 a) 2) 8)
  (check-equal? (law-size '(pow3 a)) 2)
  (check-true (< (fit-error '(pow3 a)) (fit-error 'a)))
  (check-equal? (best-law) '(pow3 a)))
