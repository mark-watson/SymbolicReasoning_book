#lang racket

;;; Arithmetic evaluator and AST size shared by the learned-proposer,
;;; CEGIS, and compositional case-study examples. Most chapters keep their
;;; own small evaluator inline so each listing reads on its own.

(provide eval-arith
         eval-expr-with-x
         ast-size)

(require racket/match)

;; Simple evaluator for (+ * -) over numbers and variables.
;; env is a hash or an alist mapping symbols to numbers ('() for closed
;; terms). An unbound variable is an error at the variable itself.
(define (eval-arith expr env)
  (define (unbound s) (error 'eval-arith "unbound variable ~a" s))
  (match expr
    [(? number? n) n]
    [(? symbol? s)
     (cond [(hash? env) (hash-ref env s (lambda () (unbound s)))]
           [(assq s env) => cdr]
           [else (unbound s)])]
    [`(+ ,a ,b) (+ (eval-arith a env) (eval-arith b env))]
    [`(- ,a ,b) (- (eval-arith a env) (eval-arith b env))]
    [`(* ,a ,b) (* (eval-arith a env) (eval-arith b env))]
    [_ (raise-argument-error 'eval-arith "arith expr" expr)]))

;; Variant that binds x as a number directly
(define (eval-expr-with-x expr xval)
  (eval-arith expr (hash 'x xval)))

;; Node count: symbols and numbers count as 1, each operator node adds 1.
;; Covers every operator used in the book's grammars.
(define (ast-size e)
  (match e
    [(or (? number?) (? symbol?)) 1]
    [`(,(or '+ '- '* '/ '<=) ,a ,b) (+ 1 (ast-size a) (ast-size b))]
    [`(,(or 'inc 'dec 'mod4 'sq 'pow2 'pow3) ,a) (+ 1 (ast-size a))]
    [`(ite ,c ,t ,f) (+ 1 (ast-size c) (ast-size t) (ast-size f))]
    [_ (raise-argument-error 'ast-size "AST" e)]))
