#lang racket

;;; Propositional Logic Evaluator
;;; Supports AND, OR, NOT, IMPLIES, IFF

(require racket/dict
         racket/match)

(provide logical-and
         logical-or
         logical-not
         logical-implies
         logical-iff
         evaluate
         make-environment
         truth-table
         truth-table-display)

;; Logical connectives: strict boolean semantics (Racket truth is any non-#f)
;; Return #t or #f only
(define (logical-and a b)
  (if (and a b) #t #f))

(define (logical-or a b)
  (if (or a b) #t #f))

(define (logical-not a)
  (if a #f #t))

(define (logical-implies a b)
  (if a (if b #t #f) #t))

(define (logical-iff a b)
  (if a (if b #t #f) (not b)))

;; Truth table: return list of (assignment result) instead of printing
;; Each assignment is a list of booleans aligned with vars
(define (truth-table vars expr)
  (define n (length vars))
  (define total (expt 2 n))
  (for/list ([i (in-range total)])
    (define assignment
      (for/list ([v vars] [k (in-naturals)])
        (if (bitwise-bit-set? i k) #t #f)))
    (define env (make-environment vars assignment))
    (list assignment (evaluate expr env))))

(define (truth-table-display vars expr)
  (for ([row (truth-table vars expr)])
    (display (first row))
    (display " => ")
    (displayln (second row))))

;; Evaluation for a single assignment
;; env is an alist of (var . boolean)
(define (evaluate expr env)
  (match expr
    [(== #t) #t]
    [(== #f) #f]
    [(? symbol? s) (dict-ref env s #f)]
    [`(not ,a) (logical-not (evaluate a env))]
    [`(and ,a ,b) (logical-and (evaluate a env) (evaluate b env))]
    [`(or ,a ,b) (logical-or (evaluate a env) (evaluate b env))]
    [`(implies ,a ,b) (logical-implies (evaluate a env) (evaluate b env))]
    [`(iff ,a ,b) (logical-iff (evaluate a env) (evaluate b env))]
    [_ (raise-argument-error 'evaluate "propositional expr" expr)]))

;; Helper to create environment from vars and truth values
(define (make-environment vars values)
  (map cons vars values))

(module+ main
  ;; Example expressions
  (define p (list 'and 'x 'y))
  (define q (list 'or 'x 'y))
  (define r (list 'implies 'x 'y))
  (define s (list 'iff 'x 'y))
  (define n (list 'not 'x))

  (define env1 (make-environment '(x y) '(#t #f)))

  (displayln "=== Propositional Logic Examples ===")
  (displayln "P AND Q with x=#t, y=#f:")
  (displayln (evaluate p env1))
  (displayln "")
  (displayln "P OR Q with x=#t, y=#f:")
  (displayln (evaluate q env1))
  (displayln "")
  (displayln "P IMPLIES Q with x=#t, y=#f:")
  (displayln (evaluate r env1))
  (displayln "")
  (displayln "P IFF Q with x=#t, y=#f:")
  (displayln (evaluate s env1))
  (displayln "")
  (displayln "NOT P with x=#t:")
  (displayln (evaluate n (make-environment '(x) '(#t))))

  ;; More complex nested formula
  ;; (x OR y) AND (x IMPLIES y) is true when y holds or when x and y agree
  (define complex '(and (or x y) (implies x y)))
  (displayln "")
  (displayln "(x OR y) AND (x IMPLIES y) with x=#t, y=#f:")
  (displayln (evaluate complex env1))

  ;; Truth table for the nested formula
  (displayln "")
  (displayln "Truth table for (x OR y) AND (x IMPLIES y):")
  (truth-table-display '(x y) complex)
  (displayln "")
  (displayln "Note: table is #f for (#f #f) and (#t #f), #t for (#f #t) and (#t #t)."))

(module+ test
  (require rackunit)
  (check-equal? (logical-and #t #t) #t)
  (check-equal? (logical-and #t #f) #f)
  (check-equal? (logical-and 1 2) #t) ; truthy values count as true
  (check-equal? (logical-or 1 2) #t)
  (check-equal? (logical-or #f #f) #f)
  (check-equal? (logical-not #f) #t)
  (check-equal? (logical-implies #t #f) #f)
  (check-equal? (logical-implies #f #t) #t)
  (check-equal? (logical-iff #t #t) #t)
  (check-equal? (logical-iff #t #f) #f)
  (check-equal? (logical-implies #t 5) #t) ; strict booleans even for truthy args
  (check-equal? (logical-iff 1 2) #t)
  (check-false (evaluate '(and x y) (make-environment '(x y) '(#t #f))))
  (check-true (evaluate '(or x y) (make-environment '(x y) '(#t #f))))
  (check-equal? (length (truth-table '(x y) '(and x y))) 4)
  (check-exn exn:fail? (lambda () (evaluate '(unknown x y) '()))))
