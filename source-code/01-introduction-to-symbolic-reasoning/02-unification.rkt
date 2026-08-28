#lang racket

;;; Unification Algorithm
;;; Finds substitutions that make two terms identical

(provide (all-defined-out))

;; Helper to extract ? from variable name
(define (get-var-base var)
  (string->symbol (substring (symbol->string var) 1)))

;; Check if a value is a variable (symbol starting with ?)
(define (var? x)
  (and (symbol? x) (char=? (string-ref (symbol->string x) 0) #\?)))

;; Substitution environment: list of (var . value) pairs
(define (subst-lookup var env)
  (let ((pair (assq var env)))
    (if pair
        (cdr pair)
        var)))

;; Apply substitution to a term
(define (subst term env)
  (cond
    ((var? term) (subst-lookup term env))
    ((pair? term) (cons (subst (car term) env) (subst (cdr term) env)))
    (else term)))

;; Occurs check: does variable x occur in term y (with substitution env)?
(define (occurs? x y env)
  (let ((y-val (subst y env)))
    (cond
      ((var? y-val) (eq? x y-val))
      ((pair? y-val)
       (or (occurs? x (car y-val) env)
           (occurs? x (cdr y-val) env)))
      (else #f))))

;; Unify two terms with respect to substitution env
(define (unify x y env)
  (let ((x-val (subst x env))
        (y-val (subst y env)))
    (cond
      ((eq? x-val y-val) env)
      ((var? x-val)
       (if (occurs? x-val y-val env)
           (error "Unification failed: occurs check" x-val y-val)
           (cons (cons x-val y-val) env)))
      ((var? y-val)
       (if (occurs? y-val x-val env)
           (error "Unification failed: occurs check" y-val x-val)
           (cons (cons y-val x-val) env)))
      ((and (pair? x-val) (pair? y-val))
       (let ((env1 (unify (car x-val) (car y-val) env)))
         (if (and (pair? (cdr x-val)) (pair? (cdr y-val)))
             (unify (cdr x-val) (cdr y-val) env1)
             env1)))
      (else (error "Unification failed" x-val y-val)))))

;; Resolve a term fully (apply substitution repeatedly)
(define (resolve term env)
  (let ((result (subst term env)))
    (cond
      ((and (var? result) (not (eq? result term)))
       (resolve result env))
      ((and (var? result) (eq? result term)) result)  ;; Return the variable itself if unresolved
      ((pair? result)
       (cons (resolve (car result) env) (resolve (cdr result) env)))
      (else result))))

;; Pretty print substitution
(define (print-env env)
  (if (null? env)
      (displayln "{}")
      (begin
        (display "{")
        (let loop ((e env))
          (when (pair? e)
            (let ((pair (car e)))
              (display (car pair))
              (display " = ")
              (display (cdr pair))
              (when (pair? (cdr e))
                (display ", "))
              (loop (cdr e)))))
        (displayln "}"))))

;; Test cases
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

;; More complex unification
(define test5 (unify '(?x loves ?y) '(mary loves john) '()))
(displayln "")
(displayln "Unify (?x loves ?y) with (mary loves john):")
(print-env test5)
(displayln "Resolved ?x:")
(displayln (resolve '?x test5))
(displayln "Resolved ?y:")
(displayln (resolve '?y test5))

;; Test that should fail
(define test6 (unify '(?x ?x) '(a b) '()))
(displayln "")
(displayln "Unify (?x ?x) with (a b) - expecting failure:")
(with-handlers ((exn:fail? (lambda (e) (displayln (exn-message e)))))
  (print-env test6))
