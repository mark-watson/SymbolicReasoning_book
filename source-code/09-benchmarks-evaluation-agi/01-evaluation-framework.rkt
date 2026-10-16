#lang racket

;;; Evaluation Framework: train vs test, size, and search cost

(provide eval-expr size candidates synthesize benchmark run-task result)

(require racket/match)

(define (eval-expr e x)
  (match e
    ['x x]
    [(? integer? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(- ,a ,b) (- (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [_ (raise-argument-error 'eval-expr "arith expr" e)]))

;; size is AST node count
(define (size e)
  (match e
    [(or 'x (? integer?)) 1]
    [`(,(or '+ '- '*) ,a ,b) (+ 1 (size a) (size b))]
    [_ 1]))

(define (candidates)
  '(x 0 1 2 3 (+ x 1) (+ x 2) (+ x x) (- x 1) (- x x)
    (* x 1) (* x 2) (* x 3) (* x x) (+ (* x 2) 1) (+ (* x x) x) (+ 1 (* x x))))

;; Returns (cons program tried), where tried counts every candidate
;; evaluated, including the one that matched.
(define (synthesize examples)
  (let loop ([rest (candidates)] [tried 1])
    (cond [(null? rest) (cons #f (- tried 1))]
          [(andmap (lambda (ex) (= (eval-expr (car rest) (car ex)) (cdr ex))) examples)
           (cons (car rest) tried)]
          [else (loop (cdr rest) (+ tried 1))])))

(define benchmark
  (list (list 'identity '((0 . 0) (1 . 1)) '((2 . 2) (3 . 3)))
        (list 'double '((1 . 2) (2 . 4)) '((3 . 6) (5 . 10)))
        (list 'square '((1 . 1) (2 . 4) (3 . 9)) '((4 . 16) (5 . 25)))
        (list 'inc '((0 . 1) (1 . 2)) '((2 . 3) (5 . 6)))
        (list 'two-x-plus-one '((0 . 1) (1 . 3) (2 . 5)) '((3 . 7) (4 . 9)))))

(struct result (name status prog train-acc test-acc size tried) #:transparent)

(define (run-task task)
  (match-define (list name train test) task)
  (match-define (cons prog tried) (synthesize train))
  (if (not prog)
      (result name 'fail #f 0.0 0.0 0 tried)
      (let* ([train-correct (count (lambda (ex) (= (eval-expr prog (car ex)) (cdr ex))) train)]
             [test-correct (count (lambda (ex) (= (eval-expr prog (car ex)) (cdr ex))) test)])
        (result name 'solved prog (/ train-correct (length train)) (/ test-correct (length test)) (size prog) tried))))

(define (report-task r)
  (displayln (format "  ~a: ~a" (result-name r) (result-status r)))
  (when (eq? (result-status r) 'solved)
    (displayln (format "    prog = ~a  (size ~a, tried ~a)" (result-prog r) (result-size r) (result-tried r)))
    (displayln (format "    train-acc=~a  test-acc=~a" (result-train-acc r) (result-test-acc r)))))

(module+ main
  (displayln "=== Evaluation Framework ===")
  (define results (map run-task benchmark))
  (for-each report-task results)
  (define solved (filter (lambda (r) (eq? (result-status r) 'solved)) results))
  (define (avg key) (if (null? solved) 0.0 (/ (apply + (map key solved)) (length solved))))
  (newline)
  (displayln (format "Solved ~a / ~a tasks" (length solved) (length benchmark)))
  (displayln (format "Average train accuracy:  ~a" (exact->inexact (avg result-train-acc))))
  (displayln (format "Average test accuracy:   ~a" (exact->inexact (avg result-test-acc))))
  (displayln (format "Average program size:    ~a" (exact->inexact (avg result-size))))
  (displayln (format "Average candidates tried: ~a" (exact->inexact (avg result-tried)))))

(module+ test
  (require rackunit)
  (check-equal? (size '(+ (* x 2) 1)) 5)
  (check-equal? (synthesize '((0 . 0) (1 . 1))) '(x . 1))
  (check-equal? (synthesize '((0 . 7))) (cons #f (length (candidates))))
  (check-equal? (result-status (run-task (list 'identity '((0 . 0) (1 . 1)) '((2 . 2) (3 . 3))))) 'solved))
