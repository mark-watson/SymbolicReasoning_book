#lang racket

;;; Propositional Logic Evaluator
;;; Supports AND, OR, NOT, IMPLIES operations

(provide (all-defined-out))

;; Logical connectives
(define (logical-and a b)
  (and (not (eq? a #f)) (not (eq? b #f))))

(define (logical-or a b)
  (or (eq? a #t) (eq? b #t)))

(define (logical-not a)
  (eq? a #f))

(define (logical-implies a b)
  (or (eq? a #f) (eq? b #t)))

(define (logical-iff a b)
  (eq? (eq? a #t) (eq? b #t)))

;; Truth table generator
(define (truth-table vars expr)
  (let ((n (length vars)))
    (let loop ((i 0))
      (when (< i (expt 2 n))
        (let-values (((mask val) (quotient/remainder i 2)))
          (let ((assignment (map (lambda (v) 
                                   (if (= (remainder (quotient i (expt 2 (index-of vars v))) 2) 1) #t #f))
                              vars)))
            (display assignment)
            (display " => ")
            (displayln (evaluate expr (make-environment vars assignment)))
            (loop (+ i 1))))))))

;; Simple evaluation for a single assignment
(define (evaluate expr env)
  (cond
    ((eq? expr #t) #t)
    ((eq? expr #f) #f)
    ((symbol? expr) (dict-ref env expr #f))
    ((and (list? expr) (= (length expr) 3))
     (let ((op (car expr))
           (a (cadr expr))
           (b (caddr expr)))
       (case op
         ((and) (logical-and (evaluate a env) (evaluate b env)))
         ((or) (logical-or (evaluate a env) (evaluate b env)))
         ((implies) (logical-implies (evaluate a env) (evaluate b env)))
         ((iff) (logical-iff (evaluate a env) (evaluate b env))))))
    ((and (list? expr) (= (length expr) 2) (eq? (car expr) 'not))
     (logical-not (evaluate (cadr expr) env)))
    (else (error "Invalid expression" expr))))

;; Helper to create environment from vars and truth values
(define (make-environment vars values)
  (map cons vars values))

;; Example expressions
(define p (list 'and 'x 'y))
(define q (list 'or 'x 'y))
(define r (list 'implies 'x 'y))
(define s (list 'iff 'x 'y))
(define n (list 'not 'x))

;; Test with specific assignments
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
(define complex '(and (or x y) (implies x y)))
(displayln "")
(displayln "(x OR y) AND (x IMPLIES y) with x=#t, y=#f:")
(displayln (evaluate complex env1))

;; Truth table for the nested formula
(displayln "")
(displayln "Truth table for (x OR y) AND (x IMPLIES y):")
(truth-table '(x y) complex)
