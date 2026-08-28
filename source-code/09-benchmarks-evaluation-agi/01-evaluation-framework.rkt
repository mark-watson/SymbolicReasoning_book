#lang racket

;;; An Evaluation Framework for Program Synthesis
;;;
;;; Benchmarks for AGI-flavored synthesis systems need to measure more
;;; than raw accuracy.  A good evaluation framework reports:
;;;   1. Train accuracy     -- did the synthesizer fit the examples?
;;;   2. Test accuracy      -- does the discovered program generalize?
;;;   3. Program size       -- how parsimonious is the solution?
;;;   4. Search efficiency  -- how many candidates were considered?
;;;
;;; This example implements such a harness and runs a toy synthesizer
;;; over a small benchmark suite, printing a per-task report and an
;;; aggregate summary.

;; ---------- tiny expression language ----------
(define (eval-expr e x)
  (match e
    ['x x]
    [(? integer? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(- ,a ,b) (- (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [_ (error 'eval-expr "bad expr ~a" e)]))

(define (size e)
  (match e
    [(or 'x (? integer?)) 1]
    [`(,(or '+ '- '*) ,a ,b) (+ 1 (size a) (size b))]
    [_ 1]))

;; ---------- toy synthesizer ----------
;; We enumerate a fixed candidate list; the enumerator is deliberately
;; simple because the point here is the evaluation harness.
(define (candidates)
  '(x
    0 1 2 3
    (+ x 1) (+ x 2) (+ x x)
    (- x 1) (- x x)
    (* x 1) (* x 2) (* x 3)
    (* x x)
    (+ (* x 2) 1) (+ (* 2 x) 1)
    (+ (* x x) x)
    (+ 1 (* x x))))

;; Returns (prog . count) where count is how many candidates were
;; evaluated before a match was found.
(define (synthesize examples)
  (let loop ((rest (candidates)) (n 0))
    (cond
      [(null? rest) (cons #f n)]
      [(andmap (lambda (ex)
                 (= (eval-expr (car rest) (car ex)) (cdr ex)))
               examples)
       (cons (car rest) n)]
      [else (loop (cdr rest) (+ n 1))])))

;; ---------- benchmark suite ----------
;; Each task is (name train-set test-set)
(define benchmark
  (list
   (list 'identity
         '((0 . 0) (1 . 1)) '((2 . 2) (3 . 3)))
   (list 'double
         '((1 . 2) (2 . 4)) '((3 . 6) (5 . 10)))
   (list 'square
         '((1 . 1) (2 . 4) (3 . 9)) '((4 . 16) (5 . 25)))
   (list 'inc
         '((0 . 1) (1 . 2)) '((2 . 3) (5 . 6)))
   (list 'two-x-plus-one
         '((0 . 1) (1 . 3) (2 . 5)) '((3 . 7) (4 . 9)))))

;; ---------- evaluation harness ----------
(define (run-task task)
  (match-define (list name train test) task)
  (define result (synthesize train))
  (define prog (car result))
  (define considered (cdr result))
  (if (not prog)
      (hash 'name name 'status 'fail
            'train-acc 0.0 'test-acc 0.0
            'size 0 'considered considered)
      (let* ((train-correct (count (lambda (ex)
                                     (= (eval-expr prog (car ex)) (cdr ex)))
                                   train))
             (test-correct (count (lambda (ex)
                                    (= (eval-expr prog (car ex)) (cdr ex)))
                                  test))
             (train-acc (/ train-correct (length train)))
             (test-acc  (/ test-correct  (length test))))
        (hash 'name name 'status 'solved
              'prog prog
              'train-acc train-acc 'test-acc test-acc
              'size (size prog) 'considered considered))))

(define (report-task r)
  (displayln (format "  ~a: ~a" (hash-ref r 'name) (hash-ref r 'status)))
  (when (eq? (hash-ref r 'status) 'solved)
    (displayln (format "    prog = ~a  (size ~a, considered ~a)"
                       (hash-ref r 'prog)
                       (hash-ref r 'size)
                       (hash-ref r 'considered)))
    (displayln (format "    train-acc=~a  test-acc=~a"
                       (hash-ref r 'train-acc)
                       (hash-ref r 'test-acc)))))

;; ---------- run the suite ----------
(displayln "=== Evaluation Framework ===")
(define results (map run-task benchmark))
(for-each report-task results)

;; aggregate
(define solved (filter (lambda (r) (eq? (hash-ref r 'status) 'solved)) results))
(define avg (lambda (key)
              (if (null? solved) 0.0
                  (/ (apply + (map (lambda (r) (hash-ref r key)) solved))
                     (length solved)))))

(newline)
(displayln (format "Solved ~a / ~a tasks" (length solved) (length benchmark)))
(displayln (format "Average train accuracy:  ~a" (exact->inexact (avg 'train-acc))))
(displayln (format "Average test accuracy:   ~a" (exact->inexact (avg 'test-acc))))
(displayln (format "Average program size:    ~a" (exact->inexact (avg 'size))))
(displayln (format "Average candidates tried:~a"
                   (exact->inexact (avg 'considered))))
