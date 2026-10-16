#lang racket

;;; Synthesis with a learned proposer: a probabilistic grammar trained on a
;;; corpus of solved programs reorders the search space, and a CEGIS verifier
;;; keeps every answer correct. The proposer stands in for an LLM: it decides
;;; which candidates to try first, never which candidates are right.

(provide all-exprs
         train-proposer
         log-prob
         uniform-order
         learned-order
         cegis-with-order)

(require racket/match
         "../utils/eval.rkt")

(define leaves '(x 1 2 3))
(define ops '(+ * -))
(define symbols (append leaves ops))

;; Every expression up to depth 2 (8,116 programs), stably sorted so
;; smaller programs come first (ties keep generation order).
(define (exprs-to-depth d)
  (if (= d 0)
      leaves
      (let ([subs (exprs-to-depth (- d 1))])
        (append leaves
                (for*/list ([op ops] [a subs] [b subs]) (list op a b))))))

(define (all-exprs)
  (sort (exprs-to-depth 2) < #:key ast-size #:cache-keys? #t))

;; Production events: each node emits (context . symbol), where context is
;; 'root or (parent-op . argument-position). This is a bigram model over
;; syntax trees, the smallest "language model of programs" that still
;; captures habits such as "the left argument of * is usually a constant".
(define (events e [ctx 'root])
  (match e
    [(list op a b) (append (list (cons ctx op))
                           (events a (cons op 0))
                           (events b (cons op 1)))]
    [s (list (cons ctx s))]))

(define (contexts) (cons 'root (for*/list ([op ops] [i '(0 1)]) (cons op i))))

;; Add-one smoothing keeps every production possible, so the proposer can
;; still reach programs unlike anything in its corpus.
(define (train-proposer corpus)
  (define counts (make-hash))
  (for* ([p corpus] [ev (events p)])
    (hash-update! counts ev add1 0))
  (for*/hash ([ctx (contexts)] [s symbols])
    (define total (for/sum ([t symbols]) (add1 (hash-ref counts (cons ctx t) 0))))
    (values (cons ctx s) (log (/ (add1 (hash-ref counts (cons ctx s) 0)) total)))))

(define (log-prob model e)
  (for/sum ([ev (events e)]) (hash-ref model ev)))

(define (uniform-order) (all-exprs))

;; Highest probability first; ties keep the size order of all-exprs.
(define (learned-order model)
  (sort (all-exprs) > #:key (lambda (e) (log-prob model e)) #:cache-keys? #t))

(define (fits? e examples)
  (andmap (lambda (ex) (= (eval-expr-with-x e (car ex)) (cdr ex))) examples))

;; CEGIS over a fixed proposal order. Returns (list program rounds tried),
;; where tried counts every candidate evaluation across all rounds.
(define (cegis-with-order order spec domain)
  (let loop ([examples (list (cons (first domain) (spec (first domain))))]
             [rounds 1]
             [tried 0])
    (define-values (cand n)
      (for/fold ([found #f] [n 0]) ([e order] #:break found)
        (values (and (fits? e examples) e) (add1 n))))
    (define cex
      (and cand
           (for/first ([x domain] #:unless (= (eval-expr-with-x cand x) (spec x))) x)))
    (cond [(not cand) (list #f rounds (+ tried n))]
          [(not cex) (list cand rounds (+ tried n))]
          [else (loop (append examples (list (cons cex (spec cex))))
                      (add1 rounds)
                      (+ tried n))])))

;; Programs "seen in training". None of the test tasks below appears here.
(define corpus
  '((+ (* 2 x) 1) (+ (* 3 x) 1) (- (* 2 x) 1) (* 2 x) (* 3 x)
    (+ (* x x) 1) (* x x) (+ x 1) (+ (* x x) x) (- (* 3 x) 2)
    (+ (* 2 x) 2) (- (* x x) 1)))

(define tasks
  (list (list "2x + 3"      (lambda (x) (+ (* 2 x) 3)))
        (list "3x - 1"      (lambda (x) (- (* 3 x) 1)))
        (list "x^2 + 2"     (lambda (x) (+ (* x x) 2)))
        (list "(x - 1)^2"   (lambda (x) (* (- x 1) (- x 1))))))

(define domain (range 0 10))

(module+ main
  (define model (train-proposer corpus))
  (define u (uniform-order))
  (define l (learned-order model))
  (printf "Search space: ~a programs up to depth 2\n" (length u))
  (printf "Proposer trained on ~a solved programs\n\n" (length corpus))
  (printf "First five proposals, uniform: ~a\n" (take u 5))
  (printf "First five proposals, learned: ~a\n\n" (take l 5))
  (printf "~a~a~a\n" (~a "task" #:width 12) (~a "uniform tried" #:width 26) "learned tried")
  (for ([t tasks])
    (match-define (list name spec) t)
    (match-define (list pu ru nu) (cegis-with-order u spec domain))
    (match-define (list pl rl nl) (cegis-with-order l spec domain))
    (printf "~a~a~a\n"
            (~a name #:width 12)
            (~a (format "~a  ~a" nu pu) #:width 26)
            (format "~a  ~a" nl pl)))
  (newline)
  (displayln "Every answer passed the verifier on x = 0..9. The proposer changed")
  (displayln "how many candidates CEGIS tried, not whether the answer is correct."))

(module+ test
  (require rackunit)
  (define model (train-proposer corpus))
  (define u (uniform-order))
  (define l (learned-order model))
  (check-equal? (length u) (length l))
  (check-true (< (log-prob model '(+ (* 2 x) 1)) 0))
  (check-true (> (log-prob model '(+ (* 2 x) 1)) (log-prob model '(- (- 3 3) (* x 1)))))
  (for ([t tasks])
    (match-define (list _ spec) t)
    (match-define (list pu _ nu) (cegis-with-order u spec domain))
    (match-define (list pl _ nl) (cegis-with-order l spec domain))
    (for ([x domain])
      (check-equal? (eval-expr-with-x pu x) (spec x))
      (check-equal? (eval-expr-with-x pl x) (spec x))))
  ;; 3x - 1 is far down the uniform order but close to the corpus
  (match-define (list _ _ nu) (cegis-with-order u (lambda (x) (- (* 3 x) 1)) domain))
  (match-define (list pl3 _ nl) (cegis-with-order l (lambda (x) (- (* 3 x) 1)) domain))
  (check-equal? pl3 '(- (* 3 x) 1))
  (check-true (< nl nu)))
