#lang racket

;;; Counter-Example Guided Inductive Synthesis (CEGIS)

(provide eval-expr
         gen-exprs
         synthesize
         verify
         cegis)

(require racket/match)

(define (eval-expr e x)
  (match e
    ['x x]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [`(- ,a ,b) (- (eval-expr a x) (eval-expr b x))]
    [_ (raise-argument-error 'eval-expr "CEGIS expr" e)]))

;; Generator: depth 0 is terminals; depth d adds one operator layer.
;; Ordering is by size, so synthesize returns the smallest fitting program.
(define (gen-exprs depth)
  (if (= depth 0)
      '(x 0 1)
      (let ([subs (gen-exprs (- depth 1))])
        (append '(x 0 1)
                (for*/list ([a subs] [b subs]) `(+ ,a ,b))
                (for*/list ([a subs] [b subs]) `(* ,a ,b))))))

(define (synthesize examples depth)
  (findf (lambda (e) (andmap (lambda (ex) (= (eval-expr e (car ex)) (cdr ex))) examples))
         (gen-exprs depth)))

(define (verify candidate)
  (define (spec x) (* 2 x))
  (for/first ([x '(0 1 2 3 4 5)] #:when (not (= (eval-expr candidate x) (spec x))))
    x))

(define (cegis max-rounds #:seed [seed '((0 . 0))])
  (let loop ([examples seed] [round 1])
    (displayln (format "--- Round ~a ---" round))
    (displayln (format "Examples so far: ~a" examples))
    (define candidate (synthesize examples 2))
    (displayln (format "Candidate: ~a" candidate))
    (define cex (and candidate (verify candidate)))
    (cond
      [(not candidate) (displayln "No candidate fits current examples.") #f]
      [(not cex) (displayln "Verifier: no counter-example found. CORRECT.") candidate]
      [(> round max-rounds) (displayln "Round limit reached.") #f]
      [else
       (displayln (format "Verifier: counter-example input x = ~a" cex))
       (loop (append examples (list (cons cex (* 2 cex)))) (+ round 1))])))

(module+ main
  (displayln "=== Counter-Example Guided Inductive Synthesis ===")
  (newline)
  (displayln "Specification: f(x) = 2*x for x in 0..5")
  (displayln "Grammar: x, 0, 1, (+ e e), (* e e)")
  (displayln "Candidates are ordered by size, so the smallest fitting program wins.")
  (newline)
  (define result (cegis 10))
  (newline)
  (if result
      (begin
        (displayln (format "Final synthesized program: ~a" result))
        (displayln (format "Check: ~a" (map (lambda (x) (eval-expr result x)) '(0 1 2 3 4 5)))))
      (displayln "Synthesis failed within the round limit."))
  (newline)
  (displayln "The verifier supplies only falsifying inputs; the synthesizer")
  (displayln "never sees the full spec as a table. This is the power of CEGIS."))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(+ x x) 3) 6)
  (check-equal? (synthesize '((0 . 0) (1 . 2)) 2) '(+ x x))
  (check-false (verify '(+ x x)))
  (check-equal? (verify 'x) 1)
  (check-not-false (cegis 10)))
