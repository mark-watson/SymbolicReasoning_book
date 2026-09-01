#lang racket

;;; Programming by Example: String Transformations

(require racket/match)
(require "../utils/string.rkt")

(provide string-op
         string-op-name
         string-op-func
         +operations+
         eval-string-expr
         apply-operation
         learn-transform)

(struct string-op (name func) #:transparent)

(define +operations+
  (list
   (string-op "reverse" string-reverse)
   (string-op "to-upper" string-upcase)
   (string-op "to-lower" string-downcase)
   (string-op "trim" string-trim)))

;; Evaluate an expression with input; supports concat, take, drop, substring
(define (eval-string-expr expr input)
  (match expr
    [(? string? s) s]
    ['input input]
    [`(concat ,args ...) (apply string-append (map (lambda (a) (eval-string-expr a input)) args))]
    [`(substring ,s ,start ,end) (substring (eval-string-expr s input) start end)]
    [`(substring ,s ,start) (substring (eval-string-expr s input) start)]
    [`(take ,s ,n) (substring (eval-string-expr s input) 0 n)]
    [`(drop ,s ,n) (substring (eval-string-expr s input) n)]
    [`(,op ,args ...) (error 'eval-string-expr "unknown op ~a" op)]
    [_ (raise-argument-error 'eval-string-expr "string expr" expr)]))

(define (apply-operation op-struct input)
  (unless (string-op? op-struct)
    (raise-argument-error 'apply-operation "string-op?" op-struct))
  ((string-op-func op-struct) input))

(define (find-op-by-name name)
  (findf (lambda (o) (equal? (string-op-name o) name)) +operations+))

;; Learn a single-op transformation that fits all examples
;; Returns the string-op struct or #f with an explanatory message in main
(define (learn-transform examples)
  (for/or ([op +operations+])
    (and (for/and ([ex examples])
           (equal? ((string-op-func op) (car ex)) (cadr ex)))
         op)))

(module+ main
  (displayln "=== Programming by Example: String Transformations ===")

  (define examples-1
    '(("john smith" "smith, john")
      ("mary jane" "jane, mary")))

  (displayln "Examples for name formatting:")
  (for ([ex examples-1])
    (displayln (format "  \"~a\" -> \"~a\"" (car ex) (cadr ex))))

  (define learned-1 (learn-transform examples-1))
  (displayln "")
  (if learned-1
      (begin
        (displayln (format "Learned transformation: ~a" (string-op-name learned-1)))
        (displayln (format "Test on \"alice bob\": ~a" (apply-operation learned-1 "alice bob"))))
      (begin
        (displayln "No single primitive fits name formatting.")
        (displayln "This DSL has no split/concat on space; a richer DSL would")
        (displayln "learn (concat (second (split input \" \")) \", \" (first ...)).")))

  (define examples-2
    '(("Hello World" "hello_world")
      ("Foo Bar" "foo_bar")))

  (displayln "")
  (displayln "Examples for snake_case (also not in single-op DSL):")
  (for ([ex examples-2])
    (displayln (format "  \"~a\" -> \"~a\"" (car ex) (cadr ex))))
  (displayln (format "learn-transform result: ~a" (learn-transform examples-2)))

  (displayln "")
  (displayln "Candidate programs in richer DSL:")
  (displayln "  - reverse, to-upper, to-lower, trim")
  (displayln "  - concat, substring, take, drop over input"))

(module+ test
  (require rackunit)
  (check-equal? (eval-string-expr '(concat "a" "b") "x") "ab")
  (check-equal? (eval-string-expr '(take "hello" 2) "ignored") "he")
  (check-equal? (eval-string-expr '(drop "hello" 2) "ignored") "llo")
  (check-equal? (eval-string-expr "lit" "input") "lit")
  (check-equal? (eval-string-expr 'input "hi") "hi")
  (define rev (find-op-by-name "reverse"))
  (check-equal? (apply-operation rev "hello") "olleh")
  (check-false (learn-transform '(("john smith" "smith, john"))))
  (check-equal? (string-op-name (learn-transform '(("HELLO" "hello")))) "to-lower"))
