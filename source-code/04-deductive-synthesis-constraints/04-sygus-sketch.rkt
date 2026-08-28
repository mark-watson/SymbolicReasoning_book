#lang racket

;;; Syntax-Guided Synthesis (SyGuS): Grammar-Constrained Search
;;;
;;; SyGuS restricts the search space with a grammar, so only well-formed
;;; programs in a domain-specific language are ever considered.
;;; We demonstrate two ideas:
;;;   1. Enumerating a grammar to synthesize max2 from I/O examples
;;;   2. Completing a "sketch" (a template with holes ??)

;; ---------- grammar ----------
;; Start  ::= IntExpr
;; IntExpr::= x | y | 0 | 1
;;          | (+ IntExpr IntExpr)
;;          | (- IntExpr IntExpr)
;;          | (ite BoolExpr IntExpr IntExpr)
;; BoolExpr::= (<= IntExpr IntExpr)
;;
;; Enumerate all sentences of the grammar by depth. Depth 0 gives the
;; terminals; each extra depth adds one level of operator nesting.
;; (ite ...) at depth d uses terminals for its boolean guard to keep the
;; enumeration small enough to run interactively.
(define (gen-int depth)
  (if (= depth 0)
      '(x y 0 1)
      (append
       '(x y 0 1)
       (for*/list ((a (gen-int (- depth 1)))
                   (b (gen-int (- depth 1))))
         `(+ ,a ,b))
       (for*/list ((a (gen-int (- depth 1)))
                   (b (gen-int (- depth 1))))
         `(- ,a ,b))
       (for*/list ((c (gen-bool 0))
                   (t (gen-int (- depth 1)))
                   (e (gen-int (- depth 1))))
         `(ite ,c ,t ,e)))))

(define (gen-bool depth)
  (for*/list ((a (gen-int depth))
              (b (gen-int depth)))
    `(<= ,a ,b)))

;; ---------- interpreter for the DSL ----------
(define (eval-dsl e x y)
  (match e
    ['x x]
    ['y y]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-dsl a x y) (eval-dsl b x y))]
    [`(- ,a ,b) (- (eval-dsl a x y) (eval-dsl b x y))]
    [`(<= ,a ,b) (<= (eval-dsl a x y) (eval-dsl b x y))]
    [`(ite ,c ,t ,f) (if (eval-dsl c x y)
                         (eval-dsl t x y)
                         (eval-dsl f x y))]))

;; ---------- part 1: SyGuS synthesis of max2 ----------
(define examples '((1 2 . 2) (3 1 . 3) (2 2 . 2) (0 5 . 5)))

(define (sygus-synthesize examples depth)
  (findf (lambda (e)
           (andmap (lambda (ex)
                     (= (eval-dsl e (car ex) (cadr ex)) (cddr ex)))
                   examples))
         (gen-int depth)))

;; ---------- part 2: sketch completion ----------
;; A template with a hole:  (ite (<= x y) ?? ??)
(define (complete-sketch holes examples)
  (findf (lambda (h)
           (let ((prog `(ite (<= x y) ,(car h) ,(cadr h))))
             (andmap (lambda (ex)
                       (= (eval-dsl prog (car ex) (cadr ex)) (cddr ex)))
                     examples)))
         (for*/list ((a holes) (b holes)) (list a b))))

(displayln "=== Syntax-Guided Synthesis (SyGuS) ===")
(newline)
(displayln "Grammar:")
(displayln "  IntExpr ::= x | y | 0 | 1 | (+ I I) | (- I I) | (ite B I I)")
(displayln "  BoolExpr ::= (<= I I)")
(newline)

(displayln "Part 1: synthesize max2 from examples (depth-2 enumeration)")
(display (format "  Examples: ~a\n" examples))
(let ((prog (sygus-synthesize examples 2)))
  (if prog
      (begin
        (displayln (format "  Synthesized: ~a" prog))
        (displayln "  Verification:")
        (for ((ex examples))
          (displayln (format "    max2(~a,~a) = ~a (expected ~a)"
                             (car ex) (cadr ex)
                             (eval-dsl prog (car ex) (cadr ex))
                             (cddr ex)))))
      (displayln "  No program found at this grammar depth.")))

(newline)
(displayln "Part 2: sketch completion")
(displayln "  Template: (ite (<= x y) ?? ??), holes from {x y 0 1}")
(let ((fill (complete-sketch '(x y 0 1) examples)))
  (if fill
      (displayln (format "  Completed sketch: (ite (<= x y) ~a ~a)"
                         (car fill) (cadr fill)))
      (displayln "  No hole assignment satisfies the examples.")))

(newline)
(displayln "The grammar prunes the search space: ill-formed or irrelevant")
(displayln "programs are never generated. Sketches let a human expert supply")
(displayln "the algorithmic skeleton while the synthesizer fills in details.")
