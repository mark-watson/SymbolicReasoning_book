#lang racket

;;; Generalization-Gap Metrics: a Mini Synthesis Leaderboard
;;;
;;; In the same spirit as modern ML leaderboards, we score multiple
;;; synthesizers across a battery of tasks and report the
;;; generalization gap -- the difference between train and test
;;; accuracy.  A system with a small gap has learned something real;
;;; a system with a large gap is memorizing.
;;;
;;; We compare three strategies:
;;;   1. nearest-neighbor memorization
;;;   2. enumerative synthesis over {x, +1, *2, *x}
;;;   3. enumerative synthesis over a richer grammar including square

;; ---------- evaluators ----------
(define (eval-linear expr xval)
  ;; expr is integer, symbol 'x, or a list (+/-/* a b)
  (cond
    [(integer? expr) expr]
    [(eq? expr 'x) xval]
    [(and (list? expr) (= (length expr) 3))
     (let ((op (first expr))
           (a  (eval-linear (second expr) xval))
           (b  (eval-linear (third  expr) xval)))
       (cond
         [(eq? op '+) (+ a b)]
         [(eq? op '-) (- a b)]
         [(eq? op '*) (* a b)]
         [else #f]))]
    [else #f]))

;; ---------- synthesizer: nearest neighbor ----------
(define (synth-nearest-neighbor train)
  ;; returns a closure (x) that does nearest-neighbor lookup
  (lambda (x)
    (let ((best (argmin (lambda (ex) (abs (- x (car ex)))) train)))
      (cdr best))))

;; ---------- synthesizer: enumerative over a fixed candidate set ----------
(define (make-enumerator cands)
  (define (synthesize train)
    (findf (lambda (e)
             (andmap (lambda (ex)
                       (= (eval-linear e (car ex)) (cdr ex)))
                     train))
           cands))
  synthesize)

(define cands-simple '(x 1 2 3 (+ x 1) (* x 2) (* x 3)))
(define cands-rich   '(x 0 1 2 3 (+ x 1) (* x 2) (* x 3)
                       (* x x) (+ (* x 2) 1) (+ (* x x) x)))

;; ---------- benchmark tasks ----------
;; Each task: (name train test)
(define tasks
  (list
   (list 'identity  '((0 . 0) (1 . 1) (2 . 2)) '((3 . 3) (4 . 4)))
   (list 'double    '((0 . 0) (1 . 2) (2 . 4)) '((3 . 6) (5 . 10)))
   (list 'square    '((1 . 1) (2 . 4) (3 . 9)) '((4 . 16) (5 . 25)))))

;; ---------- scoring ----------
;; accuracy of model fn on a dataset
(define (accuracy fn data)
  (define n (length data))
  (define hits (count (lambda (pair)
                        (equal? (fn (car pair)) (cdr pair)))
                      data))
  (if (zero? n) 0.0 (/ hits n)))

;; synthesizers produce either a closure (for NN) or an S-expr /
;; symbol-for-x (for enumerative) -- we wrap all results into a closure
(define (synth->fn result)
  (cond
    [(procedure? result) result]
    [(or (symbol? result) (list? result) (number? result))
     (lambda (x) (eval-linear result x))]
    [else (lambda (x) #f)]))

;; ---------- run ----------
(struct result (name train-acc test-acc prog))

(define (run-task taskname train test synth)
  (define model (synth->fn (synth train)))
  (define ta (accuracy model train))
  (define te (accuracy model test))
  (result taskname ta te model))

(define (display-results label runs)
  (displayln (format "--- ~a ---" label))
  (for ((r runs))
    (displayln (format "  ~a: train ~a  test ~a"
                       (result-name r)
                       (exact->inexact (result-train-acc r))
                       (exact->inexact (result-test-acc r)))))
  (define gavg (lambda (acc)
                 (/ (apply + (map acc runs)) (length runs))))
  (define g (lambda (r) (- (result-train-acc r) (result-test-acc r))))
  (displayln (format "  avg train-acc = ~a, avg test-acc = ~a, avg gap = ~a"
                     (exact->inexact (gavg result-train-acc))
                     (exact->inexact (gavg result-test-acc))
                     (exact->inexact (gavg g)))))

;; ---------- three strategies ----------
(displayln "=== Synthesis Leaderboard ===")

(define nn-runs
  (map (lambda (t)
         (apply run-task (first t) (second t) (third t)
                (list synth-nearest-neighbor)))
       tasks))
(display-results "Nearest-neighbor memorization" nn-runs)

(define simple-runs
  (map (lambda (t)
         (apply run-task (first t) (second t) (third t)
                (list (make-enumerator cands-simple))))
       tasks))
(display-results "Simple grammar  (no square)" simple-runs)

(define rich-runs
  (map (lambda (t)
         (apply run-task (first t) (second t) (third t)
                (list (make-enumerator cands-rich))))
       tasks))
(display-results "Rich grammar    (with square)" rich-runs)

(newline)
(displayln "Interpretation:")
(displayln "  - Nearest-neighbor memorizes: perfect on train, zero on test,")
(displayln "    so its generalization gap is 1.0 (as large as possible).")
(displayln "  - A simple grammar succeeds on the tasks it can express,")
(displayln "    and fails outright (0/0 accuracy) on square, which it cannot")
(displayln "    represent -- a coverage failure rather than a memorization gap.")
(displayln "  - A richer grammar covers every task and generalizes across")
(displayln "    the board, with gap 0 (no sign of overfitting).")
