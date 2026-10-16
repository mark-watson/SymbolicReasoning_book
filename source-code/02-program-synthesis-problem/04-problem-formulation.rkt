#lang racket

;;; Problem Formulation for Program Synthesis

(require racket/match)
(require "../utils/string.rkt")

(provide synthesis-problem
         synthesis-problem-name
         synthesis-problem-examples
         synthesis-problem-grammar
         synthesis-problem-verify
         synthesis-problem-metadata
         make-problem
         eval-expr
         eval-string
         specify
         verify-candidate)

(struct synthesis-problem
  (name examples grammar verify metadata)
  #:transparent)

(define (make-problem name examples grammar verify [meta '()])
  (synthesis-problem name examples grammar verify meta))

;; Helper: arithmetic evaluation
(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]
    [_ (raise-argument-error 'eval-expr "arith expr" expr)]))

;; String transformation (toy): input is list of strings
(define (eval-string prog input)
  (match prog
    ['reverse (string-reverse (car input))]
    ['to-upper (string-upcase (car input))]
    [`(concat ,a ,b)
     (string-append (eval-string a input) (eval-string b input))]
    [_ (raise-argument-error 'eval-string "string program" prog)]))

;; Example 1: Learning a linear function
(define linear-examples '((0 0) (1 2) (2 4) (3 6)))

(define linear-problem
  (make-problem
   'linear-function
   linear-examples
   '(constant + * -)
   (lambda (prog)
     (for/and ([ex linear-examples])
       (equal? (eval-expr prog '()) (cadr ex))))
   '((description . "Learn f(x) = 2x from examples (constant-only demo)"))))

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
     (for/and ([ex string-examples])
       (equal? (eval-string prog (car ex)) (cadr ex))))
   '((description . "Convert (first last) to (last, first)"))))

(define (specify examples grammar)
  (make-problem #f examples grammar #f))

(define (verify-candidate problem prog)
  (define v (synthesis-problem-verify problem))
  (if (procedure? v) (v prog) #f))

(module+ main
  (displayln "=== Problem Formulation Example ===")

  (displayln "Linear function problem:")
  (displayln (format "  Name: ~a" (synthesis-problem-name linear-problem)))
  (displayln (format "  Examples: ~a" (synthesis-problem-examples linear-problem)))
  (displayln (format "  Grammar: ~a" (synthesis-problem-grammar linear-problem)))

  (displayln "")
  (displayln "String reversal problem:")
  (displayln (format "  Name: ~a" (synthesis-problem-name string-problem)))
  (displayln (format "  Examples: ~a" (synthesis-problem-examples string-problem)))
  (displayln (format "  Grammar: ~a" (synthesis-problem-grammar string-problem)))

  (displayln "")
  (displayln "Verifying candidate for linear problem (constant 0):")
  (displayln (verify-candidate linear-problem 0))
  (displayln "Note: constant 0 matches only f(0)=0, not the full spec.")

  (displayln "")
  (displayln "Synthesis problems formally define examples, grammar, and verify.")

  (displayln "")
  (displayln (format "(concat reverse to-upper) on (john smith) -> ~a"
                     (eval-string '(concat reverse to-upper) '("john" "smith")))))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(+ 1 2) '()) 3)
  (check-equal? (eval-string 'reverse '("hello")) "olleh")
  (check-equal? (eval-string '(concat reverse reverse) '("a" "b")) "aa")
  (check-exn exn:fail? (lambda () (eval-string 'no-such-op '("a"))))
  (check-false (verify-candidate linear-problem 123))
  (check-false (verify-candidate (specify '((0 0)) '(+)) 0))
  (check-equal? (synthesis-problem-name (specify '((0 0)) '(+))) #f))
