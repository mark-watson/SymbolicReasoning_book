#lang racket

;;; Enumerative Program Search: Bottom-Up
;;; Demonstrates systematic exploration of the program space

(provide (all-defined-out))

;; Language definition: simple arithmetic expressions
;; Grammar: expr ::= number | (+ expr expr) | (* expr expr) | (- expr expr)

;; Evaluate an expression
(define (eval-expr expr env)
  (cond
    ((number? expr) expr)
    ((and (list? expr) (= (length expr) 3))
     (let ((op (car expr))
           (a (eval-expr (cadr expr) env))
           (b (eval-expr (caddr expr) env)))
       (case op
         ((+) (+ a b))
         ((*) (* a b))
         ((-) (- a b))
         (else (error "Unknown operator" op)))))
    (else (error "Invalid expression" expr))))

;; Check if expression matches all examples
(define (matches-examples? expr examples)
  (for/and ((ex examples))
    (let ((input (car ex))
          (output (cadr ex))
          (pred (eval-expr expr '())))
      (equal? pred output))))

;; Generate programs up to given size (limited to avoid explosion)
(define (generate-programs max-size)
  (if (= max-size 1)
      (list 0 1 2 3 4 5)
      (let ((base (list 0 1 2 3 4 5)))
        (append base
                (for*/list ((a (generate-programs (max 1 (- max-size 1))))
                            (b (generate-programs (max 1 (- max-size 1))))
                            (op '(+ *)))
                  (list op a b))))))

;; Bottom-up search: enumerate programs and test
(define (bottom-up-search examples max-size)
  (let ((candidates (generate-programs max-size)))
    (findf (lambda (p) (matches-examples? p examples)) candidates)))

;; Test examples
(displayln "=== Enumerative Search Example ===")

(define examples 
  '((0 0)     ; f(0) = 0
    (1 2)     ; f(1) = 2  
    (2 4)     ; f(2) = 4
    (3 6)))   ; f(3) = 6

(displayln "Target examples: f(0)=0, f(1)=2, f(2)=4, f(3)=6")
(displayln "Note: Our simple language doesn't include variables!")
(displayln "Searching for f(x) = constant expression, not f(x) = 2x")
(displayln "")

;; Test program generation
(displayln "Programs of size 1:")
(define progs-1 (generate-programs 1))
(display "  ") (displayln progs-1)

(displayln "")
(displayln "Programs of size 2:")
(define progs-2 (generate-programs 2))
(display "  Sample: ") 
(displayln (take progs-2 15))

(displayln "")
(displayln "Programs of size 3:")
(define progs-3 (generate-programs 3))
(display "  Count: ") (displayln (length progs-3))

;; Search for constant solutions only
(displayln "")
(displayln "Note: Our language has no variables, so we can't learn f(x)=2x.")
(displayln "Instead, this demonstrates the program enumeration process.")
(displayln "The next chapters show how to handle variables and more complex languages.")
