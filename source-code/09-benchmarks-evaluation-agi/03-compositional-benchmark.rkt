#lang racket

;;; SCAN-Style Compositional Generalization

(provide command-table expand-command length-bounded-synth parse-expr eval-program)

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

(define test-examples
  '(((walk and look twice) . ("walk" "look" "walk" "look"))
    ((jump and run twice) . ("jump" "run" "jump" "run"))))

(define (length-bounded-synth tokens bounded)
  ;; Filter to known commands before expanding, so 'and'/'twice' do not error
  (define known (filter (lambda (t) (assoc t command-table)) tokens))
  (if (<= (length tokens) bounded)
      (expand-command known)
      (expand-command (take known bounded))))

(define (parse-expr tokens)
  (define (parse-primary toks)
    (cond [(null? toks) #f]
          [(member (car toks) '(walk look jump run)) (cons (car toks) (cdr toks))]
          [else #f]))
  (define (parse-seq toks)
    (let loop ([acc (parse-primary toks)])
      (if (not acc) #f
          (let ([rest (cdr acc)])
            (if (and (pair? rest) (eq? (car rest) 'and))
                (let ([rhs (parse-primary (cdr rest))])
                  (if rhs (loop (cons (list 'and (car acc) (car rhs)) (cdr rhs))) acc))
                acc)))))
  (let ([s (parse-seq tokens)])
    (if (not s) #f
        (let ([rest (cdr s)])
          (if (and (pair? rest) (eq? (car rest) 'twice))
              (cons (list 'twice (car s)) (cdr rest))
              s)))))

(define (eval-program p)
  (match p
    [(? symbol? a) (or (cdr (assoc a command-table)) (error 'eval-program "unknown ~a" a))]
    [`(and ,x ,y) (append (eval-program x) (eval-program y))]
    [`(twice ,x) (append (eval-program x) (eval-program x))]
    [_ (error 'eval-program "bad program ~a" p)]))

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
  (summarize (lambda (t) (length-bounded-synth t 2)) "Length-bounded synthesizer (max depth 2)")
  (summarize (lambda (t) (let ([p (parse-expr t)]) (if p (eval-program (car p)) 'PARSE-FAIL))) "Compositional synthesizer (recursive parse)"))

(module+ test
  (require rackunit)
  (check-equal? (eval-program (car (parse-expr '(walk and look twice)))) '("walk" "look" "walk" "look"))
  (check-equal? (length-bounded-synth '(walk and look twice) 2) '("walk" "look"))
  (check-exn exn:fail? (lambda () (expand-command '(foo)))))
