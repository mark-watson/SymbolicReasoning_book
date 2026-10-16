#lang racket

;;; Program Synthesis for Autonomous Skill Acquisition

(provide skill-library add-skill! get-skill
         eval-expr synthesize-skill compose-skills)

(require racket/match)

(define skill-library (make-parameter '()))

(define (add-skill! name fn)
  (skill-library (cons (cons name fn) (skill-library))))

(define (get-skill name)
  (define p (assoc name (skill-library)))
  (if p (cdr p) (raise-argument-error 'get-skill "known skill" name)))

(define (eval-expr e x)
  (match e
    ['x x]
    [(? integer? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [_ (raise-argument-error 'eval-expr "arith expr" e)]))

(define (synthesize-skill examples)
  (define candidates '(x (+ x x) (* x x) (+ x 1) (* 2 x) (* 3 x)))
  (findf (lambda (e) (andmap (lambda (ex) (= (eval-expr e (car ex)) (cdr ex))) examples))
         candidates))

(define (compose-skills name1 name2 new-name)
  (add-skill! new-name (lambda (x) ((get-skill name1) ((get-skill name2) x)))))

(module+ main
  (skill-library '())
  (displayln "=== Autonomous Skill Acquisition ===")
  (define double-examples '((1 . 2) (2 . 4) (3 . 6)))
  (define double-prog (synthesize-skill double-examples))
  (add-skill! 'double (lambda (x) (eval-expr double-prog x)))
  (displayln (format "Acquired skill 'double: ~a" double-prog))

  (define square-examples '((1 . 1) (2 . 4) (3 . 9)))
  (define square-prog (synthesize-skill square-examples))
  (add-skill! 'square (lambda (x) (eval-expr square-prog x)))
  (displayln (format "Acquired skill 'square: ~a" square-prog))

  (compose-skills 'double 'square 'two-x-squared)
  (displayln "Composed 'double and 'square into 'two-x-squared")
  (define xs '(0 1 2 3 4 5))
  (displayln (format "Results on inputs ~a: ~a" xs (map (lambda (x) ((get-skill 'two-x-squared) x)) xs)))
  (displayln "")
  (displayln "System discovered 'double and 'square from examples and combined them.")
  (displayln "The candidate set is fixed; a richer system would enumerate a grammar."))

(module+ test
  (require rackunit)
  (skill-library '())
  (check-equal? (synthesize-skill '((1 . 2) (2 . 4) (3 . 6))) '(+ x x))
  (check-equal? (synthesize-skill '((1 . 1) (2 . 4) (3 . 9))) '(* x x))
  (add-skill! 'double (lambda (x) (* 2 x)))
  (add-skill! 'square (lambda (x) (* x x)))
  (check-equal? ((get-skill 'double) 3) 6)
  ;; compose-skills applies name2 first, then name1: double(square(x))
  (compose-skills 'double 'square 'two-x-squared)
  (check-equal? (map (get-skill 'two-x-squared) '(0 1 2 3)) '(0 2 8 18))
  (check-exn exn:fail? (lambda () (get-skill 'no-such-skill))))
