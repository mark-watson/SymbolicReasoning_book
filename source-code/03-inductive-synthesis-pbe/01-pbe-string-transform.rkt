#lang racket

;;; Programming by Example: String Transformations
;;; Demonstrates learning string manipulations from input-output examples

(provide (all-defined-out))

;; Helper function
(define (string-reverse s)
  (list->string (reverse (string->list s))))

;; Simple string DSL with basic operations
(struct string-op (name func) #:transparent)

;; Available operations in our DSL
(define +operations+
  (list
   (string-op "reverse" string-reverse)
   (string-op "to-upper" string-upcase)
   (string-op "to-lower" string-downcase)
   (string-op "trim" string-trim)))

;; Evaluate an expression with input
(define (eval-string-expr expr input)
  (cond
    ((string? expr) expr)
    ((eq? expr 'input) input)
    ((and (pair? expr) (> (length expr) 0))
     (let ((op (car expr))
           (args (map (lambda (a) (eval-string-expr a input)) (cdr expr))))
       (case op
         ((concat) (apply string-append args))
         ((substring) (apply substring args))
         ((take) (substring (car args) 0 (cadr args)))
         ((drop) (substring (car args) (cadr args)))
         (else (error "Unknown op" op)))))
    (else (error "Invalid expression" expr))))

;; Find operation by name and apply
(define (apply-operation op-name input)
  (let ((op (findf (lambda (o) (equal? (string-op-name o) op-name)) 
                   +operations+)))
    (if op ((string-op-func op) input) input)))

;; Learn transformations from examples
(define (learn-transform examples)
  (for/or ((op +operations+))
    ;; Check if this operation works for ALL examples
    (if (for/and ((ex examples))
          (equal? ((string-op-func op) (car ex)) (cadr ex)))
        op
        #f)))

;; Example: Name formatting tasks
(displayln "=== Programming by Example: String Transformations ===")

;; Example 1: "john smith" -> "smith, john"
(define examples-1
  '(("john smith" "smith, john")
    ("mary jane" "jane, mary")))

(displayln "Examples for name formatting:")
(for ((ex examples-1))
  (display "  \"") 
  (display (car ex))
  (display "\" -> \"")
  (display (cadr ex))
  (displayln "\""))

;; Learned transformation
(define learned-1 (learn-transform examples-1))
(displayln "")
(if learned-1
    (begin
      (display "Learned transformation: ")
      (displayln learned-1)
      (display "Test on \"alice bob\": ")
      (displayln (apply-operation learned-1 "alice bob")))
    (displayln "No simple transformation found"))

;; Example 2: Case conversion
(define examples-2
  '(("Hello World" "hello_world")
    ("Foo Bar" "foo_bar")))

(displayln "")
(displayln "Examples for snake_case:")
(for ((ex examples-2))
  (display "  \"") 
  (display (car ex))
  (display "\" -> \"")
  (display (cadr ex))
  (displayln "\""))

;; Generate candidate programs
(displayln "")
(displayln "Candidate programs:")
(displayln "  - reverse, to-upper, to-lower, trim")
(displayln "  - concat (op1 input) (op2 input)")
