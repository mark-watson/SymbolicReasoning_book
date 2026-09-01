#lang racket

;;; Arithmetic evaluators shared by enumerative, stochastic, CEGIS, SyGuS,
;;; generalization, hypothesis generation, and leaderboard chapters
;;; Provides small evaluators over s-expression grammars with explicit
;;; variable handling and a node-count size function.

(provide eval-arith
         eval-arith-env
         eval-expr-with-x
         ast-size
         ast-size-extended)

(require racket/match)

;; Simple evaluator for (+ * -) over numbers and variable 'x.
;; env is a hash mapping 'x -> value, or '() for closed terms.
(define (eval-arith expr env)
  (match expr
    [(? number? n) n]
    [(? symbol? s)
     (cond [(hash? env) (hash-ref env s s)]
           [(list? env) (let ([p (assq s env)]) (if p (cdr p) s))]
           [else s])]
    [`(+ ,a ,b) (+ (eval-arith a env) (eval-arith b env))]
    [`(- ,a ,b) (- (eval-arith a env) (eval-arith b env))]
    [`(* ,a ,b) (* (eval-arith a env) (eval-arith b env))]
    [_ (raise-argument-error 'eval-arith "arith expr" expr)]))

;; Variant that binds x as a number directly
(define (eval-expr-with-x expr xval)
  (eval-arith expr (hash 'x xval)))

;; For callers that pass x as positional arg (legacy)
(define (eval-arith-env expr x)
  (eval-expr-with-x expr x))

;; Node count for (+ - *) trees; symbols and numbers count as 1
(define (ast-size e)
  (match e
    [(or (? number? ) (? symbol?)) 1]
    [`(,(or '+ '- '*) ,a ,b) (+ 1 (ast-size a) (ast-size b))]
    [`(,(or 'inc 'dec 'mod4 'sq 'pow2 'pow3) ,a) (+ 1 (ast-size a))]
    [`(ite ,c ,t ,f) (+ 1 (ast-size c) (ast-size t) (ast-size f))]
    [`(<= ,a ,b) (+ 1 (ast-size a) (ast-size b))]
    [_ 1]))

;; Extended size that also handles (/ sq pow2 pow3 ite <=)
(define (ast-size-extended e)
  (match e
    [(or (? number? ) (? symbol?)) 1]
    [`(sq ,a) (+ 1 (ast-size-extended a))]
    [`(pow2 ,a) (+ 1 (ast-size-extended a))]
    [`(pow3 ,a) (+ 1 (ast-size-extended a))]
    [`(,(or '+ '- '* '/) ,a ,b) (+ 1 (ast-size-extended a) (ast-size-extended b))]
    [`(,(or 'inc 'dec 'mod4) ,a) (+ 1 (ast-size-extended a))]
    [`(ite ,c ,t ,f) (+ 1 (ast-size-extended c) (ast-size-extended t) (ast-size-extended f))]
    [`(<= ,a ,b) (+ 1 (ast-size-extended a) (ast-size-extended b))]
    [_ 1]))
