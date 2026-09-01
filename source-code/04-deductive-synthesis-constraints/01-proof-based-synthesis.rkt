#lang racket

;;; Deductive Synthesis via Sequent-Style Proof Search
;;; A program is derived as a byproduct of proving a specification.
;;;
;;; Specification example:
;;;   "For natural x and y, there exists z with z = x + y"
;;; Proving this theorem constructively yields the program z = (+ x y).

(provide derive
         show-derivation)

;; derive: prop env -> (cons proof program) or #f
(define (derive prop env)
  (match prop
    [(? symbol? s)
     (if (memq s env)
         (cons (list 'axiom s) s)
         #f)]
    [`(and ,p ,q)
     (let ([a (derive p env)]
           [b (derive q env)])
       (if (and a b)
           (cons (list 'and-intro (car a) (car b))
                 (list 'cons (cdr a) (cdr b)))
           #f))]
    ;; Existential with equality: witness is (+ x y). The two bound names
    ;; must coincide (v == v2) or the rule does not apply.
    [`(ex ,v (= ,v2 (+ ,x ,y)))
     #:when (and (eq? v v2) (memq x env) (memq y env))
     (cons (list 'exists-intro v (list '+ x y))
           (list '+ x y))]
    [`(=> ,p ,q)
     (let ([r (derive q (cons p env))])
       (if r
           (cons (list 'imp-intro p (car r))
                 (list 'lambda (list p) (cdr r)))
           #f))]
    [_ #f]))

(define (show-derivation spec env)
  (displayln (format "Spec:   ~a" spec))
  (displayln (format "Assume: ~a" env))
  (let ([r (derive spec env)])
    (if r
        (begin
          (displayln (format "Proof:  ~a" (car r)))
          (displayln (format "Program: ~a" (cdr r))))
        (displayln "No derivation found.")))
  (newline))

(module+ main
  (displayln "=== Deductive Synthesis: Programs from Proofs ===")
  (newline)

  (show-derivation 'x '(x y))
  (show-derivation '(and x y) '(x y))
  (show-derivation '(ex z (= z (+ x y))) '(x y))
  (show-derivation '(=> x (=> y (ex z (= z (+ x y))))) '())
  (show-derivation '(ex z (= z (+ x w))) '(x y))
  ;; Additional negative case: missing second conjunct
  (show-derivation '(and x z) '(x y))

  (displayln "Each successful proof carries a program term as computational")
  (displayln "content (Curry-Howard). Failed proofs say the spec needs more")
  (displayln "assumptions or constructors."))

(module+ test
  (require rackunit)
  (check-not-false (derive 'x '(x y)))
  (check-false (derive 'z '(x y)))
  (check-not-false (derive '(and x y) '(x y)))
  (check-false (derive '(and x z) '(x y)))
  (check-not-false (derive '(ex z (= z (+ x y))) '(x y)))
  (check-false (derive '(ex z (= z (+ x w))) '(x y)))
  (check-equal? (cdr (derive '(ex z (= z (+ x y))) '(x y))) '(+ x y)))
