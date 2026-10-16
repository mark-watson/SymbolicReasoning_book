#lang racket

;;; Unification Algorithm
;;; Finds substitutions that make two terms identical
;;; Variables are symbols starting with ? (e.g., ?x). The symbol ? alone
;;; is treated as a variable and will unify with anything.

(require racket/match)

(provide var?
         subst
         subst-lookup
         occurs?
         unify
         resolve
         print-env)

;; Check if a value is a variable (symbol starting with ?)
(define (var? x)
  (and (symbol? x)
       (> (string-length (symbol->string x)) 0)
       (char=? (string-ref (symbol->string x) 0) #\?)))

;; Follow a binding chain ?x -> ?y -> a to its end
(define (subst-lookup var env)
  (let loop ([v var])
    (define p (assq v env))
    (if p (loop (cdr p)) v)))

;; Apply substitution to a term, chasing chains
(define (subst term env)
  (cond
    [(var? term) (subst-lookup term env)]
    [(pair? term) (cons (subst (car term) env) (subst (cdr term) env))]
    [else term]))

;; Occurs check: does variable x occur in term y (after applying env)?
(define (occurs? x y env)
  (let ([y-val (subst y env)])
    (cond
      [(var? y-val) (eq? x y-val)]
      [(pair? y-val)
       (or (occurs? x (car y-val) env)
           (occurs? x (cdr y-val) env))]
      [else #f])))

;; Unify two terms with respect to substitution env
;; On failure raises exn:fail. Callers that prefer #f should use with-handlers.
(define (unify x y env)
  (let ([x-val (subst x env)]
        [y-val (subst y env)])
    (cond
      [(equal? x-val y-val) env]
      [(var? x-val)
       (if (occurs? x-val y-val env)
           (error 'unify "occurs check failed: ~a in ~a" x-val y-val)
           (cons (cons x-val y-val) env))]
      [(var? y-val)
       (if (occurs? y-val x-val env)
           (error 'unify "occurs check failed: ~a in ~a" y-val x-val)
           (cons (cons y-val x-val) env))]
      [(and (pair? x-val) (pair? y-val))
       (let ([env1 (unify (car x-val) (car y-val) env)])
         (unify (cdr x-val) (cdr y-val) env1))]
      [else (error 'unify "clash: ~a vs ~a" x-val y-val)])))

;; Resolve a term fully (chase all bindings)
(define (resolve term env)
  (let ([result (subst term env)])
    (cond
      [(var? result)
       (if (eq? result term) result (resolve result env))]
      [(pair? result)
       (cons (resolve (car result) env) (resolve (cdr result) env))]
      [else result])))

;; Pretty print substitution
(define (print-env env)
  (if (null? env)
      (displayln "{}")
      (begin
        (display "{")
        (let loop ([e env] [first? #t])
          (when (pair? e)
            (unless first? (display ", "))
            (display (format "~a = ~a" (caar e) (cdar e)))
            (loop (cdr e) #f)))
        (displayln "}"))))

(module+ main
  (displayln "=== Unification Examples ===")

  (define test1 (unify '(?x) '(a) '()))
  (displayln "Unify (?x) with (a):")
  (print-env test1)

  (define test2 (unify '(?x ?y) '(a b) '()))
  (displayln "")
  (displayln "Unify (?x ?y) with (a b):")
  (print-env test2)

  (define test3 (unify '(?x ?y ?x) '(a b a) '()))
  (displayln "")
  (displayln "Unify (?x ?y ?x) with (a b a):")
  (print-env test3)
  (displayln "Resolved ?x:")
  (displayln (resolve '?x test3))
  (displayln "Resolved ?y:")
  (displayln (resolve '?y test3))

  (define test4 (unify '(f ?x) '(f (g a)) '()))
  (displayln "")
  (displayln "Unify (f ?x) with (f (g a)):")
  (print-env test4)
  (displayln "Resolved ?x:")
  (displayln (resolve '?x test4))

  (define test5 (unify '(?x loves ?y) '(mary loves john) '()))
  (displayln "")
  (displayln "Unify (?x loves ?y) with (mary loves john):")
  (print-env test5)
  (displayln "Resolved ?x:")
  (displayln (resolve '?x test5))
  (displayln "Resolved ?y:")
  (displayln (resolve '?y test5))

  (displayln "")
  (displayln "Unify (?x ?x) with (a b) - expecting failure:")
  (with-handlers ([exn:fail? (lambda (e) (displayln (exn-message e)))])
    (print-env (unify '(?x ?x) '(a b) '())))

  (displayln "")
  (displayln "Unify (?x . ?y) with (a . b):")
  (print-env (unify '(?x . ?y) '(a . b) '()))

  (displayln "")
  (displayln "Chain ?x->?y, ?y->a:")
  (define chained (unify '?x '?y '()))
  (define chained2 (unify '?y 'a chained))
  (displayln (format "resolve ?x = ~a (should be a)" (resolve '?x chained2))))

(module+ test
  (require rackunit)
  (check-equal? (resolve '?x (unify '(?x) '(a) '())) 'a)
  (check-equal? (resolve '?y (unify '(?x ?y) '(a b) '())) 'b)
  (check-exn exn:fail? (lambda () (unify '(?x ?x) '(a b) '())))
  (check-exn exn:fail? (lambda () (unify '?x '(f ?x) '())))
  (check-equal? (resolve '?x (unify '(?x . ?y) '(a . b) '())) 'a)
  (check-equal? (resolve '?y (unify '(?x . ?y) '(a . b) '())) 'b)
  (check-equal? (subst-lookup '?x '((?x . ?y) (?y . a))) 'a)
  (check-true (var? '?x))
  (check-false (var? 'x))
  (check-false (var? 42)))
