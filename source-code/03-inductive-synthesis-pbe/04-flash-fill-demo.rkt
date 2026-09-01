#lang racket

;;; Flash Fill Demo: Learning Data Transformations

(require "../utils/string.rkt")

(provide transformation
         transformation-name
         transformation-func
         +transforms+
         transform-fits?
         learn-transform
         flash-fill)

(struct transformation (name func) #:transparent)

(define +transforms+
  (list
   (transformation "reverse" string-reverse)
   (transformation "lower" string-downcase)
   (transformation "upper" string-upcase)
   (transformation "trim" string-trim)))

(define (transform-fits? func examples)
  (for/and ([ex examples])
    (equal? (func (car ex)) (cadr ex))))

(define (learn-transform examples)
  (for/or ([t +transforms+])
    (and (transform-fits? (transformation-func t) examples) t)))

(define (flash-fill examples)
  (define t (learn-transform examples))
  (if t (transformation-name t) #f))

(module+ main
  (displayln "=== Flash Fill Demonstration ===")

  (define phone-examples
    '(("1234567890" "123-456-7890")
      ("1234567891" "123-456-7891")
      ("1234567892" "123-456-7892")))

  (displayln "Input examples (phone formatting):")
  (for ([ex phone-examples]) (displayln (format "  ~a -> ~a" (car ex) (cadr ex))))
  (displayln "Note: This toy DSL has only whole-string ops, so phone")
  (displayln "formatting cannot be learned. Real FlashFill uses substring")
  (displayln "extraction with regex and position logic.")

  (displayln "")
  (displayln "Simple whole-string transformations that can be learned:")

  (define case-example '(("HELLO" "hello")))
  (define learned-case (flash-fill case-example))
  (if learned-case
      (displayln (format "  Learned: ~a  \"HELLO\" -> ~a" learned-case (string-downcase "HELLO")))
      (displayln "No transformation learned"))

  (define name-examples
    '(("john smith" "smith, john")
      ("mary jane" "jane, mary")))

  (displayln "")
  (displayln (format "Name reversal examples: ~a" name-examples))
  (displayln (format "flash-fill result: ~a (needs split/concat)" (flash-fill name-examples)))
  (displayln "For complex patterns, Traditional PBE uses:")
  (displayln "  - Substring extraction with regex")
  (displayln "  - Position-based indexing")
  (displayln "  - Context-aware pattern matching"))

(module+ test
  (require rackunit)
  (check-equal? (flash-fill '(("HELLO" "hello"))) "lower")
  (check-equal? (flash-fill '(("hello" "HELLO"))) "upper")
  (check-false (flash-fill '(("john smith" "smith, john"))))
  (check-false (flash-fill '(("1234567890" "123-456-7890")))))
