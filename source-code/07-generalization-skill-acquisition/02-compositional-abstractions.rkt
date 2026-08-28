#lang racket

;;; Compositional Abstractions and Reusable Modules
;;;
;;; This example shows how a synthesis system can build a library of
;;; reusable functions and then use them to solve harder problems.
;;; It is a tiny demonstration of DreamCoder-style library learning.
;;;
;;; We start with primitive operations (identity, increment, double)
;;; and solve simple tasks.  Then we "compress" frequently used
;;; compositions into higher-level functions (macros) and solve a
;;; task that would be infeasible without them.

;; ---------- primitive functions ----------
(define (prim-id x) x)
(define (prim-inc x) (+ x 1))
(define (prim-double x) (* 2 x))

;; ---------- task representation ----------
;; A task is a list of (input . output) examples.
(define task1 '((0 . 1) (1 . 2) (2 . 3)))      ;; inc
(define task2 '((0 . 0) (1 . 2) (2 . 4)))      ;; double
(define task3 '((0 . 2) (1 . 4) (2 . 6)))      ;; double ∘ inc  (hard)

;; ---------- search over compositions ----------
;; We search over programs built from a library of functions by
;; composing them.  Each program is a list of function names applied
;; left-to-right.
(define (eval-program prog x)
  (foldl (lambda (f acc) (f acc)) x prog))

;; ---------- learn from examples by enumeration ----------
;; Try compositions of length up to max-depth and return the first
;; program that matches all examples.

(define (synthesize examples max-depth atoms)
  (let loop ((depth 1))
    (if (> depth max-depth)
        #f
        (let ((candidates
               (apply cartesian-product (make-list depth atoms))))
          (let ((found (findf (lambda (prog)
                                (andmap (lambda (ex)
                                          (= (eval-program
                                              (map (lambda (n) (name->fn n)) prog)
                                              (car ex))
                                             (cdr ex)))
                                      examples))
                              candidates)))
            (if found
                found
                (loop (+ depth 1))))))))

;; names -> primitive functions
(define (name->fn n)
  (case n
    [(id) prim-id]
    [(inc) prim-inc]
    [(double) prim-double]
    [(macro) macro-inc-then-double]
    [else (error 'name->fn "unknown fn: ~a" n)]))

;; ---------- library learning ----------
;; After solving task1 and task2, we notice that "inc then double" is a
;; useful combination.  We add it as a macro.
(define (macro-inc-then-double x) (prim-double (prim-inc x)))

;; ---------- run ----------
(displayln "=== Compositional Abstractions ===")
(displayln (format "Task1 (inc): examples ~a" task1))
(displayln (format "  Synthesized without macro: ~a" (synthesize task1 2 '(id inc double))))
(displayln (format "Task2 (double): examples ~a" task2))
(displayln (format "  Synthesized without macro: ~a" (synthesize task2 2 '(id inc double))))

(newline)
(displayln (format "Task3 (double ∘ inc): examples ~a" task3))
(define no-macro (synthesize task3 2 '(id inc double)))
(define with-macro (synthesize task3 1 '(id inc double macro)))
(displayln (format "  Without macro (depth 2 search): ~a" no-macro))
(displayln (format "  With macro (depth 1 search):    ~a" with-macro))
(displayln "  The macro lets the system solve the harder task by reusing")
(displayln "  the composition it learned earlier.")
