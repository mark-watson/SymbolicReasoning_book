#lang racket

;;; Generalization-Gap Metrics: Mini Synthesis Leaderboard

(provide eval-linear synth-nearest-neighbor make-enumerator
         cands-simple cands-rich tasks accuracy synth->fn result)

(require racket/match)

(define (eval-linear expr xval)
  (match expr
    [(? integer? n) n]
    ['x xval]
    [`(+ ,a ,b) (+ (eval-linear a xval) (eval-linear b xval))]
    [`(- ,a ,b) (- (eval-linear a xval) (eval-linear b xval))]
    [`(* ,a ,b) (* (eval-linear a xval) (eval-linear b xval))]
    [_ #f]))

(define (synth-nearest-neighbor train)
  (lambda (x)
    (cdr (argmin (lambda (ex) (abs (- x (car ex)))) train))))

(define (make-enumerator cands)
  (lambda (train)
    (findf (lambda (e) (andmap (lambda (ex) (= (eval-linear e (car ex)) (cdr ex))) train)) cands)))

(define cands-simple '(x 1 2 3 (+ x 1) (* x 2) (* x 3)))
(define cands-rich   '(x 0 1 2 3 (+ x 1) (* x 2) (* x 3) (* x x) (+ (* x 2) 1) (+ (* x x) x)))

(define tasks
  (list (list 'identity '((0 . 0) (1 . 1) (2 . 2)) '((3 . 3) (4 . 4)))
        (list 'double '((0 . 0) (1 . 2) (2 . 4)) '((3 . 6) (5 . 10)))
        (list 'square '((1 . 1) (2 . 4) (3 . 9)) '((4 . 16) (5 . 25)))))

(define (accuracy fn data)
  (if (null? data) 0.0
      (/ (count (lambda (p) (equal? (fn (car p)) (cdr p))) data) (length data))))

(define (synth->fn result)
  (cond [(procedure? result) result]
        [(or (symbol? result) (list? result) (number? result)) (lambda (x) (eval-linear result x))]
        [(not result) (lambda (x) 'no-program)]
        [else (lambda (x) #f)]))

(struct result (name train-acc test-acc prog) #:transparent)

(define (run-task taskname train test synth)
  (define raw (synth train))
  (define model (synth->fn raw))
  (result taskname (accuracy model train) (accuracy model test) raw))

(define (display-results label runs)
  (displayln (format "--- ~a ---" label))
  (for ([r runs])
    (define tag (if (not (result-prog r)) "no-coverage" (format "prog ~a" (result-prog r))))
    (displayln (format "  ~a: train ~a  test ~a  ~a"
                       (result-name r)
                       (exact->inexact (result-train-acc r))
                       (exact->inexact (result-test-acc r))
                       tag)))
  (define gavg (lambda (acc) (/ (apply + (map acc runs)) (length runs))))
  (define gap (lambda (r) (- (result-train-acc r) (result-test-acc r))))
  (displayln (format "  avg train-acc = ~a, avg test-acc = ~a, avg gap = ~a"
                     (exact->inexact (gavg result-train-acc))
                     (exact->inexact (gavg result-test-acc))
                     (exact->inexact (gavg gap))))
  (void))

(module+ main
  (displayln "=== Synthesis Leaderboard ===")
  (define nn-runs (map (lambda (t) (apply run-task (append t (list synth-nearest-neighbor)))) tasks))
  (display-results "Nearest-neighbor memorization" nn-runs)
  (define simple-runs (map (lambda (t) (apply run-task (append t (list (make-enumerator cands-simple))))) tasks))
  (display-results "Simple grammar  (no square)" simple-runs)
  (define rich-runs (map (lambda (t) (apply run-task (append t (list (make-enumerator cands-rich))))) tasks))
  (display-results "Rich grammar    (with square)" rich-runs)
  (newline)
  (displayln "Nearest-neighbor has gap 1.0 (memorizes). Simple grammar has a")
  (displayln "coverage failure on square (no program found) vs a gap. Rich")
  (displayln "grammar covers all tasks with gap 0."))

(module+ test
  (require rackunit)
  (check-equal? (eval-linear '(+ x 1) 2) 3)
  (check-equal? ((synth->fn ((make-enumerator cands-rich) '((0 . 0) (1 . 1)))) 5) 5)
  (check-equal? (exact->inexact (result-train-acc (run-task 'square '((1 . 1) (2 . 4) (3 . 9)) '((4 . 16) (5 . 25)) (make-enumerator cands-simple)))) 0.0))
