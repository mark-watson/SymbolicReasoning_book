#lang racket

;;; Deductive Synthesis via Sequent-Style Proof Search
;;; A program is derived as a byproduct of proving a specification.
;;;
;;; Specification example:
;;;   "For natural x and y, there exists z with z = x + y"
;;; Proving this theorem constructively yields the program z = (+ x y).

;; A proof goal: (goal spec-term context)
;; spec-term is a tiny logic, e.g. (and p q), (or p q), (ex z body)
(struct goal (prop env) #:transparent)

;; Derive a term proving prop, or #f if no derivation found.
;; Returns a pair (proof-term . program-term)
(define (derive prop env)
  (match prop
    ;; Axiom: a fact already in the environment gives us the variable itself
    [(? symbol? s)
     (if (memq s env)
         (cons (list 'axiom s) s)
         #f)]

    ;; Conjunction: prove both parts, program is the pair of sub-programs
    [`(and ,p ,q)
     (let ((a (derive p env))
           (b (derive q env)))
       (if (and a b)
           (cons (list 'and-intro (car a) (car b))
                 (list 'cons (cdr a) (cdr b)))
           #f))]

    ;; Existential over naturals with an equality body:
    ;; (ex z (= z (+ x y)))  -- the witness is computed from env values
    [`(ex ,v (= ,v2 (+ ,x ,y)))
     #:when (and (eq? v v2) (memq x env) (memq y env))
     (cons (list 'exists-intro v (list '+ x y))
           (list '+ x y))]

    ;; Implication introduction: assume the premise, derive conclusion.
    ;; The extracted program is a lambda.
    [`(=> ,p ,q)
     (let ((r (derive q (cons p env))))
       (if r
           (cons (list 'imp-intro p (car r))
                 (list 'lambda (list p) (cdr r)))
           #f))]

    [_ #f]))

(define (show-derivation spec env)
  (display "Spec:   ") (displayln spec)
  (display "Assume: ") (displayln env)
  (let ((r (derive spec env)))
    (if r
        (begin
          (display "Proof:  ") (displayln (car r))
          (display "Program: ") (displayln (cdr r)))
        (displayln "No derivation found.")))
  (newline))

(displayln "=== Deductive Synthesis: Programs from Proofs ===")
(newline)

;; 1. Simple fact extraction
(show-derivation 'x '(x y))

;; 2. Conjunction: build a pair
(show-derivation '(and x y) '(x y))

;; 3. Existential with equality: witness computation is the program
(show-derivation '(ex z (= z (+ x y))) '(x y))

;; 4. Nested: function that returns the sum witness
(show-derivation '(=> x (=> y (ex z (= z (+ x y))))) '())

;; 5. A spec we cannot prove from the given environment
(show-derivation '(ex z (= z (+ x w))) '(x y))

(displayln "Each successful proof carries a program term as its computational")
(displayln "content (Curry-Howard correspondence). Failed proofs tell us the")
(displayln "specification needs more assumptions or constructors.")
