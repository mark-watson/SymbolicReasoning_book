#lang racket

;;; Compositional Abstractions: DreamCoder-style library learning (hand-rolled macro)

(provide prim-id prim-inc prim-double
         macro-inc-then-double
         eval-program synthesize name->fn
         task1 task2 task3)

(define (prim-id x) x)
(define (prim-inc x) (+ x 1))
(define (prim-double x) (* 2 x))
(define (macro-inc-then-double x) (prim-double (prim-inc x)))

(define task1 '((0 . 1) (1 . 2) (2 . 3)))
(define task2 '((0 . 0) (1 . 2) (2 . 4)))
(define task3 '((0 . 2) (1 . 4) (2 . 6)))

(define (eval-program prog x) (foldl (lambda (f acc) (f acc)) x prog))

(define (name->fn n)
  (case n
    [(id) prim-id] [(inc) prim-inc] [(double) prim-double]
    [(macro) macro-inc-then-double]
    [else (raise-argument-error 'name->fn "known fn" n)]))

(define (synthesize examples max-depth atoms)
  ;; max-depth counts composed steps; candidates at depth d = |atoms|^d
  (let loop ([depth 1])
    (if (> depth max-depth) #f
        (let* ([candidates (apply cartesian-product (make-list depth atoms))]
               [found (findf (lambda (prog)
                               (andmap (lambda (ex)
                                         (= (eval-program (map name->fn prog) (car ex)) (cdr ex)))
                                       examples))
                             candidates)])
          (or found (loop (+ depth 1)))))))

(module+ main
  (displayln "=== Compositional Abstractions ===")
  (displayln (format "Task1 (inc): ~a -> ~a" task1 (synthesize task1 2 '(id inc double))))
  (displayln (format "Task2 (double): ~a -> ~a" task2 (synthesize task2 2 '(id inc double))))
  (newline)
  (displayln (format "Task3 (double∘inc): ~a" task3))
  (define no-macro (synthesize task3 2 '(id inc double)))
  (define with-macro (synthesize task3 1 '(id inc double macro)))
  (displayln (format "  Without macro (depths 1-2, up to 3+9 candidates): ~a" no-macro))
  (displayln (format "  With macro    (depth 1, up to 4 candidates):     ~a" with-macro))
  (displayln "Macro is hand-added; a full DreamCoder system would compress")
  (displayln "frequent compositions automatically."))

(module+ test
  (require rackunit)
  (check-equal? (synthesize task1 2 '(id inc double)) '(inc))
  (check-equal? (synthesize task2 2 '(id inc double)) '(double))
  (check-equal? (synthesize task3 2 '(id inc double)) '(inc double))
  (check-equal? (synthesize task3 1 '(id inc double macro)) '(macro)))
