#lang racket

;;; Program Synthesis for Autonomous Skill Acquisition
;;;
;;; This example demonstrates a tiny "skill library":
;;;   * The system starts with no skills.
;;;   * It acquires simple skills by synthesis from examples.
;;;   * It then composes those skills into more complex skills.
;;;   * The entire process runs autonomously: no human writes the skills.
;;;
;;; Skills are represented as named Racket functions.  The library is a
;;; mutable association list.

(define skill-library '())

(define (add-skill! name fn)
  (set! skill-library (cons (cons name fn) skill-library)))

(define (get-skill name)
  (let ((p (assoc name skill-library)))
    (if p (cdr p)
        (error 'get-skill "skill not found: ~a" name))))

;; ---------- skill synthesis from examples ----------
;; For simplicity each new skill is synthesized as a small program from
;; the grammar of arithmetic expressions over x.

(define (eval-expr e x)
  (match e
    ['x x]
    [(? integer? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]))

(define (synthesize-skill examples max-depth)
  ;; very small enumeration: just try x, x+x, x*x, x+1, x*2, x*3
  (let ((candidates '(x (+ x x) (* x x) (+ x 1) (* 2 x) (* 3 x))))
    (findf (lambda (e)
             (andmap (lambda (ex)
                       (= (eval-expr e (car ex)) (cdr ex)))
                     examples))
           candidates)))

;; ---------- skill composition ----------
;; Compose two skills: (compose f g) x = f(g(x)).
(define (compose-skills name1 name2 new-name)
  (let ((f (get-skill name1))
        (g (get-skill name2)))
    (add-skill! new-name (lambda (x) (f (g x))))))

;; ---------- run ----------
(displayln "=== Autonomous Skill Acquisition ===")

;; acquire 'double from examples
(define double-examples '((1 . 2) (2 . 4) (3 . 6)))
(define double-prog (synthesize-skill double-examples 1))
(add-skill! 'double (lambda (x) (eval-expr double-prog x)))
(displayln (format "Acquired skill 'double: ~a" double-prog))

;; acquire 'square from examples
(define square-examples '((1 . 1) (2 . 4) (3 . 9)))
(define square-prog (synthesize-skill square-examples 1))
(add-skill! 'square (lambda (x) (eval-expr square-prog x)))
(displayln (format "Acquired skill 'square: ~a" square-prog))

;; compose: 2*(x*x)
(compose-skills 'double 'square 'two-x-squared)
(displayln "Composed 'double and 'square into 'two-x-squared")

;; use the composed skill on new inputs
(define xs '(0 1 2 3 4 5))
(displayln (format "Results on inputs ~a: ~a"
                   xs
                   (map (lambda (x) ((get-skill 'two-x-squared) x)) xs)))

(displayln "")
(displayln "Interpretation:")
(displayln "  The system did not require a human to write the composed")
(displayln "  skill; it discovered 'double and 'square from examples and")
(displayln "  then combined them into a new capability.")
