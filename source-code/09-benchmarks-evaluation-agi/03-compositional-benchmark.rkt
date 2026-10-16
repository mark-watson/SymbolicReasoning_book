#lang racket

;;; SCAN-Style Compositional Generalization

(provide command-table expand-command length-bounded-synth parse-expr eval-program
         interpret train-examples test-examples)

(require racket/match)

(define command-table '((walk . ("walk")) (look . ("look")) (jump . ("jump")) (run . ("run"))))

(define (expand-command tokens)
  (for/fold ([out '()]) ([t tokens])
    (match (assoc t command-table)
      [#f (raise-argument-error 'expand-command "known command" t)]
      [(cons _ steps) (append out steps)])))

(define train-examples
  '(((walk) . ("walk")) ((look) . ("look")) ((jump) . ("jump"))
    ((walk and look) . ("walk" "look")) ((look and walk) . ("look" "walk"))
    ((jump and look) . ("jump" "look")) ((walk twice) . ("walk" "walk")) ((look twice) . ("look" "look"))))

;; As in SCAN, 'and' binds more loosely than 'twice':
;; "walk and look twice" means walk, then (look twice).
;; 'run' never appears in training, so the second test needs a primitive
;; the learner has only seen in the command table, combined in a new way.
(define test-examples
  '(((walk and look twice) . ("walk" "look" "look"))
    ((jump and run twice) . ("jump" "run" "run"))))

;; Baseline that ignores structure: expand the first `bounded` primitive
;; commands and drop the modifiers.
(define (length-bounded-synth tokens bounded)
  (define known (filter (lambda (t) (assoc t command-table)) tokens))
  (expand-command (take known (min bounded (length known)))))

;; Grammar (and binds loosest):
;;   seq     ::= term ('and' term)*
;;   term    ::= primary 'twice'?
;;   primary ::= walk | look | jump | run
;; Returns the program, or #f unless every token is consumed.
(define (parse-expr tokens)
  ;; each parser returns (cons tree remaining-tokens) or #f
  (define (parse-primary toks)
    (and (pair? toks)
         (assoc (car toks) command-table)
         (cons (car toks) (cdr toks))))
  (define (parse-term toks)
    (define p (parse-primary toks))
    (cond [(not p) #f]
          [(and (pair? (cdr p)) (eq? (cadr p) 'twice))
           (cons (list 'twice (car p)) (cddr p))]
          [else p]))
  (define (parse-seq toks)
    (let loop ([acc (parse-term toks)])
      (cond [(not acc) #f]
            [(and (pair? (cdr acc)) (eq? (cadr acc) 'and))
             (define rhs (parse-term (cddr acc)))
             (and rhs (loop (cons (list 'and (car acc) (car rhs)) (cdr rhs))))]
            [else acc])))
  (define s (parse-seq tokens))
  (and s (null? (cdr s)) (car s)))

(define (eval-program p)
  (match p
    [(? symbol? a)
     (match (assoc a command-table)
       [#f (error 'eval-program "unknown command ~a" a)]
       [(cons _ steps) steps])]
    [`(and ,x ,y) (append (eval-program x) (eval-program y))]
    [`(twice ,x) (append (eval-program x) (eval-program x))]
    [_ (error 'eval-program "bad program ~a" p)]))

;; Parse then evaluate; 'PARSE-FAIL when the command is not in the grammar
(define (interpret tokens)
  (define p (parse-expr tokens))
  (if p (eval-program p) 'PARSE-FAIL))

(module+ main
  (displayln "=== SCAN-Style Compositional Generalization ===")
  (displayln (format "Train examples: ~a tasks" (length train-examples)))
  (displayln (format "Test examples : ~a tasks" (length test-examples)))
  (newline)
  (define (summarize fn label)
    (displayln (format "--- ~a ---" label))
    (for ([ex test-examples])
      (define got (fn (car ex)))
      (displayln (format "  ~a -> ~a (expected ~a) ~a" (car ex) got (cdr ex) (if (equal? got (cdr ex)) "OK" "FAIL")))))
  (displayln (format "Compositional interpreter reproduces all ~a train examples: ~a"
                     (length train-examples)
                     (for/and ([ex train-examples]) (equal? (interpret (car ex)) (cdr ex)))))
  (newline)
  (summarize (lambda (t) (length-bounded-synth t 2)) "Length-bounded baseline (first 2 commands)")
  (summarize interpret "Compositional interpreter (recursive parse)"))

(module+ test
  (require rackunit)
  (check-equal? (parse-expr '(walk and look twice)) '(and walk (twice look)))
  (check-equal? (interpret '(walk and look twice)) '("walk" "look" "look"))
  (check-equal? (interpret '(walk twice and look)) '("walk" "walk" "look"))
  (for ([ex (append train-examples test-examples)])
    (check-equal? (interpret (car ex)) (cdr ex)))
  ;; leftover or unknown tokens are a parse failure, not silently dropped
  (check-false (parse-expr '(walk walk walk)))
  (check-false (parse-expr '(walk and)))
  (check-false (parse-expr '(fly)))
  (check-exn #rx"unknown command" (lambda () (eval-program 'fly)))
  (check-equal? (length-bounded-synth '(walk and look twice) 2) '("walk" "look"))
  (check-equal? (length-bounded-synth '(walk and and) 2) '("walk"))
  (check-exn exn:fail? (lambda () (expand-command '(foo)))))
