#lang racket

;;; Tiny ARC-Style Task
;;;
;;; ARC (Abstraction and Reasoning Corpus) tasks give a few
;;; input/output grid pairs and ask for the transformation rule that
;;; generalizes to a held-out test input.  We work with 1-D "grids"
;;; (lists of small integers) for clarity, but the logic is the same.
;;;
;;; The hidden rule for this task: reverse the list.
;;;
;;; A synthesizer enumerates candidate transformations from a small
;;; DSL (reverse, sort, sort-desc, inc-each, double-each, identity)
;;; and selects the one consistent with the training pairs.

;; ---------- DSL primitives ----------
(define (t-identity xs) xs)
(define (t-reverse xs) (reverse xs))
(define (t-sort xs) (sort xs <))
(define (t-sort-desc xs) (sort xs >))
(define (t-inc-each xs) (map (lambda (x) (+ x 1)) xs))
(define (t-double-each xs) (map (lambda (x) (* 2 x)) xs))

;; Each candidate is (name . fn)
(define dsl
  (list (cons 'identity   t-identity)
        (cons 'reverse    t-reverse)
        (cons 'sort       t-sort)
        (cons 'sort-desc  t-sort-desc)
        (cons 'inc-each   t-inc-each)
        (cons 'double     t-double-each)))

;; ---------- ARC-style task ----------
;; Two training pairs
(define train
  (list (cons '(1 4 2 3) '(3 2 4 1))
        (cons '(2 3 4 1) '(1 4 3 2))))

;; One held-out test input, with expected output
(define test-input  '(5 1 3 2))
(define test-output '(2 3 1 5))

;; ---------- synthesizer ----------
;; Find every DSL primitive that is consistent with all training pairs.
(define (consistent-with-train? fn)
  (andmap (lambda (pair)
            (equal? (fn (car pair)) (cdr pair)))
          train))

(define (solve-arc train-pairs)
  (filter (lambda (entry)
            (consistent-with-train? (cdr entry)))
          dsl))

(define matches (solve-arc train))

;; ---------- report ----------
(displayln "=== Tiny ARC-Style Task ===")
(displayln (format "Train pairs: ~a" train))
(displayln (format "Consistent transformations: ~a" (map car matches)))

(for ((m matches))
  (let ((pred ((cdr m) test-input)))
    (displayln (format "  ~a predicts ~a on test input ~a (expected ~a) -> ~a"
                       (car m) pred test-input test-output
                       (if (equal? pred test-output) "CORRECT" "WRONG")))))

(displayln "")
(displayln "Interpretation:")
(displayln "  The DSL primitive 'reverse is uniquely consistent with both")
(displayln "  training pairs and correctly predicts the held-out test.")
(displayln "  This is the ARC evaluation pattern in miniature: 2-or-3")
(displayln "  examples define the rule, and one grid tests generalization.")
