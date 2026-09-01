#lang racket

;;; Syntax-Guided Synthesis (SyGuS): Grammar-Constrained Search
;;; 1. Enumerate a grammar to synthesize max2
;;; 2. Complete a sketch (ite (<= x y) ?? ??)

(provide gen-int
         gen-bool
         eval-dsl
         sygus-synthesize
         complete-sketch)

(require racket/match)

;; Grammar keeps ite guards shallow (gen-bool 0) to bound enumeration
(define (gen-int depth)
  (if (= depth 0)
      '(x y 0 1)
      (append
       '(x y 0 1)
       (for*/list ([a (gen-int (- depth 1))] [b (gen-int (- depth 1))]) `(+ ,a ,b))
       (for*/list ([a (gen-int (- depth 1))] [b (gen-int (- depth 1))]) `(- ,a ,b))
       (for*/list ([c (gen-bool 0)] [t (gen-int (- depth 1))] [e (gen-int (- depth 1))]) `(ite ,c ,t ,e)))))

(define (gen-bool depth)
  (for*/list ([a (gen-int depth)] [b (gen-int depth)]) `(<= ,a ,b)))

(define (eval-dsl e x y)
  (match e
    ['x x]
    ['y y]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-dsl a x y) (eval-dsl b x y))]
    [`(- ,a ,b) (- (eval-dsl a x y) (eval-dsl b x y))]
    [`(<= ,a ,b) (<= (eval-dsl a x y) (eval-dsl b x y))]
    [`(ite ,c ,t ,f) (if (eval-dsl c x y) (eval-dsl t x y) (eval-dsl f x y))]
    [_ (raise-argument-error 'eval-dsl "SyGuS expr" e)]))

(define examples '((1 2 . 2) (3 1 . 3) (2 2 . 2) (0 5 . 5)))

(define (sygus-synthesize examples depth)
  (findf (lambda (e) (andmap (lambda (ex) (= (eval-dsl e (car ex) (cadr ex)) (cddr ex))) examples))
         (gen-int depth)))

(define (complete-sketch holes examples)
  (findf (lambda (h)
           (define prog `(ite (<= x y) ,(car h) ,(cadr h)))
           (andmap (lambda (ex) (= (eval-dsl prog (car ex) (cadr ex)) (cddr ex))) examples))
         (for*/list ([a holes] [b holes]) (list a b))))

(module+ main
  (displayln "=== Syntax-Guided Synthesis (SyGuS) ===")
  (newline)
  (displayln "Grammar:")
  (displayln "  IntExpr ::= x | y | 0 | 1 | (+ I I) | (- I I) | (ite B I I)")
  (displayln "  BoolExpr ::= (<= I I)  [depth 0 only, to bound search]")
  (newline)

  (displayln "Part 1: synthesize max2 from examples (depth-2 enumeration)")
  (displayln (format "  Examples: ~a" examples))
  (let ([prog (sygus-synthesize examples 2)])
    (if prog
        (begin
          (displayln (format "  Synthesized: ~a" prog))
          (displayln (format "  Note: (+ 0 e) is not simplified; grammar keeps it as is."))
          (displayln "  Verification:")
          (for ([ex examples])
            (displayln (format "    max2(~a,~a) = ~a (expected ~a)"
                               (car ex) (cadr ex) (eval-dsl prog (car ex) (cadr ex)) (cddr ex)))))
        (displayln "  No program found at this grammar depth.")))

  (newline)
  (displayln "Part 2: sketch completion")
  (displayln "  Template: (ite (<= x y) ?? ??), holes from {x y 0 1}")
  (match (complete-sketch '(x y 0 1) examples)
    [#f (displayln "  No hole assignment satisfies the examples.")]
    [(list a b) (displayln (format "  Completed sketch: (ite (<= x y) ~a ~a)" a b))])

  (newline)
  (displayln "The grammar prunes ill-formed programs; sketches let a human")
  (displayln "supply the skeleton while the synthesizer fills holes."))

(module+ test
  (require rackunit)
  (check-equal? (eval-dsl '(+ x y) 2 3) 5)
  (check-equal? (eval-dsl '(ite (<= x y) y x) 2 5) 5)
  (check-equal? (eval-dsl '(ite (<= x y) y x) 5 2) 5)
  (check-not-false (sygus-synthesize examples 2))
  (check-equal? (complete-sketch '(x y 0 1) examples) '(y x)))
