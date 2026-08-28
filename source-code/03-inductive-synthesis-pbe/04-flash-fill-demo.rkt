#lang racket

;;; Flash Fill Demo: Learning Data Transformations
;;; Similar to Excel's Flash Fill feature

(provide (all-defined-out))

;; Helper function  
(define (string-reverse s)
  (list->string (reverse (string->list s))))

;; Simple DSL for string transformations
(struct transformation (name func))

(define +transforms+
  (list
   (transformation "reverse" string-reverse)
   (transformation "lower" string-downcase)
   (transformation "upper" string-upcase)))

;; Apply transformation and check against examples
(define (transform-fits? func examples)
  (for/and ((ex examples))
    (let ((input (car ex))
          (output (cadr ex)))
      (equal? (func input) output))))

;; Learn transformation from examples
(define (learn-transform examples)
  (for/or ((transform +transforms+))
    (let ((func (transformation-func transform)))
      (if (transform-fits? func examples)
          transform
          #f))))

;; Interactive-style demo
(define (flash-fill examples)
  (let ((learned (learn-transform examples)))
    (if learned
        (transformation-name learned)
        #f)))

;; Example: Phone number formatting
(displayln "=== Flash Fill Demonstration ===")

(define phone-examples
  '(("1234567890" "123-456-7890")
    ("1234567891" "123-456-7891")
    ("1234567892" "123-456-7892")))

(displayln "Input examples:")
(for ((ex phone-examples))
  (display "  ") (displayln ex))

;; Our simple DSL doesn't handle pattern-based transformation
;; So we demonstrate with simple operations
(displayln "")
(displayln "Simple transformations can learn:")

(define case-example '(("HELLO" "hello")))
(define learned-case (flash-fill case-example))
(if learned-case
    (begin
      (display "Learned: ") (displayln learned-case)
      (display "  \"HELLO\" -> ")
      (displayln (string-downcase "HELLO")))
    (displayln "No transformation learned"))

;; Name reversal example
(define name-examples
  '(("john smith" "smith, john")
    ("mary jane" "jane, mary")))

(displayln "")
(displayln "For complex pattern-based transformations (like name reversal):")
(displayln "Traditional PBE systems use more sophisticated techniques:")
(displayln "  - Substring extraction with regular expressions")
(displayln "  - Position-based indexing")
(displayln "  - Context-aware pattern matching")
