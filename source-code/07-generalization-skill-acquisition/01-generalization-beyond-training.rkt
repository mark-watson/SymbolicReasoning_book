#lang racket

;;; Generalizing Beyond the Training Distribution
;;; Modular arithmetic f(x)=(x+1) mod 4 learned from 4 examples suffices for all x.

(provide eval-expr
         candidates
         satisfies?
         synthesize
         hidden-f)

(require racket/match)

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
    [_ (raise-argument-error 'eval-expr "arith expr" e)]))

;; A fixed, hand-written candidate set: all leaves, unary and binary terms
;; over leaves, plus a few deeper mod4 forms. A real system would
;; enumerate these from a grammar; the point here is what happens once a
;; fitting program is found, not how large the search is.
(define (candidates)
  (define leaves '(x 0 1 2 3))
  (define unary (append (map (lambda (a) `(inc ,a)) leaves)
                        (map (lambda (a) `(dec ,a)) leaves)
                        (map (lambda (a) `(mod4 ,a)) leaves)))
  (define binary
    (append
     (for*/list ([a leaves] [b leaves]) `(+ ,a ,b))
     (for*/list ([a leaves] [b leaves]) `(- ,a ,b))
     (for*/list ([a leaves] [b leaves]) `(* ,a ,b))
     (for*/list ([u unary] [b leaves]) `(+ ,u ,b))
     (for*/list ([u unary] [b leaves]) `(* ,u ,b))
     '((mod4 (+ x x)) (mod4 (* x x)) (mod4 (+ x 1))
       (+ (mod4 x) 1) (+ 1 (mod4 x)) (* (mod4 x) 2) (* 2 (mod4 x)))))
  (remove-duplicates (append leaves unary binary)))

(define (satisfies? prog examples)
  (andmap (lambda (ex) (= (eval-expr prog (car ex)) (cdr ex))) examples))

(define (synthesize examples)
  (findf (lambda (e) (satisfies? e examples)) (candidates)))

(define (hidden-f x) (modulo (+ x 1) 4))
(define train-examples '((0 . 1) (1 . 2) (2 . 3) (3 . 0)))

(define (nn-predict x examples)
  (cdr (argmin (lambda (ex) (abs (- x (car ex)))) examples)))

(module+ main
  (define prog (synthesize train-examples))
  (displayln "=== Generalizing Beyond Training Distribution ===")
  (displayln (format "Training examples: ~a" train-examples))
  (displayln (format "Nearest-neighbor on unseen x=4: ~a (memorizes)" (nn-predict 4 train-examples)))
  (displayln (format "Synthesized program: ~a" prog))
  (displayln (format "Synthesized on unseen: ~a" (map (lambda (x) (eval-expr prog x)) '(4 5 6 7 8))))
  (displayln (format "Hidden function:       ~a" (map hidden-f '(4 5 6 7 8)))))

(module+ test
  (require rackunit)
  (check-equal? (hidden-f 3) 0)
  (check-equal? (eval-expr '(mod4 (+ x 1)) 3) 0)
  (check-equal? (synthesize train-examples) '(mod4 (+ x 1)))
  (check-false (equal? (nn-predict 4 train-examples) (hidden-f 4)))
  (check-not-false (member '(mod4 (+ x 1)) (candidates))))
