#lang racket

;;; Problem Formulation for Program Synthesis
;;; Defines the synthesis problem formally

(provide (all-defined-out))

;; SynthesisProblem structure
(struct synthesis-problem
  (name            ; Symbolic name
   examples        ; Input-output examples
   grammar         ; Allowed operations/types
   verify          ; Verification function
   metadata))      ; Additional information

;; Create a synthesis problem
(define (make-problem name examples grammar verify (meta '()))
  (synthesis-problem name examples grammar verify meta))

;; Example 1: Learning a linear function
(define linear-examples
  '((0 0) (1 2) (2 4) (3 6)))  ; f(x) = 2x

(define linear-problem
  (make-problem
   'linear-function
   linear-examples
   '(constant + * -)
   (lambda (prog)
     (for/and ((ex linear-examples))
       (equal? (eval-expr prog '()) (cadr ex))))
   '((description . "Learn f(x) = 2x from examples"))))

;; Helper: evaluation
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
         (else (error "Unknown op" op)))))
    (else (error "Invalid expr" expr))))

;; Example 2: String transformation (Flash Fill style)
(define string-examples
  '((("john" "smith") "smith, john")
    (("mary" "jane") "jane, mary")))

(define string-problem
  (make-problem
   'name-reversal
   string-examples
   '(concat reverse to-upper)
   (lambda (prog)
     (for/and ((ex string-examples))
       (equal? (apply string-append (eval-string prog (car ex)))
               (cadr ex))))
   '((description . "Convert (first last) to (last, first)"))))

;; Helper: string transformation
(define (eval-string prog input)
  (cond
    ((eq? prog 'reverse) (string-reverse (car input)))
    ((eq? prog 'to-upper) (string-upcase (car input)))
    ((and (list? prog) (= (length prog) 3))
     (let ((op (car prog))
           (a (eval-string (cadr prog) input))
           (b (eval-string (cadr prog) input)))
       (case op
         ((concat) (string-append a b))
         (else (error "Unknown op" op)))))
    (else input)))

(define (string-reverse s)
  (list->string (reverse (string->list s))))

;; Problem specification
(define (specify examples grammar)
  (make-problem #f examples grammar #f))

;; Verification of candidate program
(define (verify-candidate problem prog)
  ((synthesis-problem-verify problem) prog))

;; Test
(displayln "=== Problem Formulation Example ===")

(displayln "Linear function problem:")
(display "  Name: ") (displayln (synthesis-problem-name linear-problem))
(display "  Examples: ") (displayln (synthesis-problem-examples linear-problem))
(display "  Grammar: ") (displayln (synthesis-problem-grammar linear-problem))

(display "\n")
(displayln "String reversal problem:")
(display "  Name: ") (displayln (synthesis-problem-name string-problem))
(display "  Examples: ") (displayln (synthesis-problem-examples string-problem))
(display "  Grammar: ") (displayln (synthesis-problem-grammar string-problem))

;; Verify a candidate
(displayln "")
(displayln "Verifying candidate program for linear problem:")
(displayln "Since our language has no variables, using a constant approximation:")
(let ((const-prog 123))  ; Any constant
  (displayln (verify-candidate linear-problem const-prog)))

(displayln "")
(displayln "Synthesis problems formally define:")
(displayln "  - What behavior is wanted (examples)")
(displayln "  - What programs are allowed (grammar)")
(displayln "  - How to check correctness (verify)")
(displayln "  - Additional context (metadata)")
