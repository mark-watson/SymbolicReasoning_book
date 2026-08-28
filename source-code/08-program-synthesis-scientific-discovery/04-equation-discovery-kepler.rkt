#lang racket

;;; Case Study: Equation Discovery -- Kepler's Third Law
;;;
;;; Kepler's third law: T^2 is proportional to a^3, where T is the
;;; orbital period and a is the semi-major axis.  Given simulated
;;; astronomical observations (noisy), we search a grammar of
;;; power-law relations and rediscover T^2 = k * a^3.
;;;
;;; The case study puts together the chapter's themes:
;;;   * hypothesis = program         (enumerate candidate laws)
;;;   * data efficiency              (only 6 observations)
;;;   * parsimony                    (rank with a simplicity penalty)

;; ---------- evaluator ----------
(define (eval-law e a)
  ;; laws are expressions in terms of a (semi-major axis), producing T^2
  (match e
    ['a a]
    [(? number? n) n]
    [`(+ ,x ,y) (+ (eval-law x a) (eval-law y a))]
    [`(* ,x ,y) (* (eval-law x a) (eval-law y a))]
    [`(pow2 ,x) (let ((v (eval-law x a))) (* v v))]
    [`(pow3 ,x) (let ((v (eval-law x a))) (* v v v))]
    [_ (error 'eval-law "bad ~a" e)]))

(define (law-size e)
  (match e
    [(or 'a (? number?)) 1]
    [`(,(or 'pow2 'pow3) ,x) (+ 1 (law-size x))]
    [`(,(or '+ '*) ,x ,y) (+ 1 (law-size x) (law-size y))]
    [_ 999]))

;; ---------- grammar of candidate laws ----------
(define (gen-laws)
  (define atoms '(a 1 2 3))
  (define unary (append (map (lambda (x) `(pow2 ,x)) atoms)
                        (map (lambda (x) `(pow3 ,x)) atoms)))
  ;; combine atoms/unary with multiplication and addition
  (append atoms unary
          (for*/list ((x atoms) (y (append atoms unary))) `(* ,x ,y))
          (for*/list ((x (list 'a)) (y unary)) `(* ,x ,y))
          (for*/list ((x atoms) (y unary)) `(+ ,x ,y))))

;; ---------- simulated observations ----------
;; True law: T^2 = a^3 (in normalized units, k=1).
;; We add small multiplicative noise.
(define observations
  '((1.0  .  1.02)     ; a=1, T^2 ~ a^3 = 1
    (1.5  .  3.40)     ; a=1.5, T^2 = 3.375
    (2.0  .  7.95)     ; a=2, T^2 = 8
    (2.5  . 15.70)     ; a=2.5, T^2 = 15.625
    (3.0  . 27.10)     ; a=3, T^2 = 27
    (3.5  . 42.80)))   ; a=3.5, T^2 = 42.875

;; ---------- scoring ----------
(define (fit-error law)
  (apply + (map (lambda (obs)
                  (let ((d (- (eval-law law (car obs)) (cdr obs))))
                    (* d d)))
                observations)))

(define (score law)
  (+ (fit-error law) (* 0.1 (law-size law))))

;; ---------- run ----------
(displayln "=== Equation Discovery: Kepler's Third Law ===")
(displayln (format "Observations (a . T^2): ~a pairs" (length observations)))
(newline)

(define ranked
  (sort (map (lambda (l) (list l (fit-error l) (law-size l) (score l)))
             (gen-laws))
        (lambda (x y) (< (fourth x) (fourth y)))))

(displayln "Top candidates (law, fit error, size, score):")
(for ((r (take ranked 6)))
  (displayln (format "  T^2 = ~a   err=~a size=~a score=~a"
                     (first r)
                     (exact->inexact (second r))
                     (third r)
                     (exact->inexact (fourth r)))))

(newline)
(define best (first (first ranked)))
(displayln (format "Discovered law: T^2 = ~a" best))
(displayln "This is Kepler's third law: the square of the orbital period")
(displayln "scales with the cube of the semi-major axis.")

;; ---------- verification on held-out data ----------
(newline)
(displayln "Verification on held-out a values (4.0, 4.5):")
(define held-out '((4.0 . 64.0) (4.5 . 91.125)))
(for ((obs held-out))
  (displayln (format "  a=~a predicted T^2=~a actual ~a"
                     (car obs)
                     (exact->inexact (eval-law best (car obs)))
                     (cdr obs))))
