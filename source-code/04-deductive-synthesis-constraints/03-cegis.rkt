#lang racket

;;; Counter-Example Guided Inductive Synthesis (CEGIS)

(provide eval-expr
         gen-exprs
         synthesize
         verify
         cegis)

(require racket/match
         (only-in "../utils/eval.rkt" ast-size))

(define (eval-expr e x)
  (match e
    ['x x]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [`(- ,a ,b) (- (eval-expr a x) (eval-expr b x))]
    [_ (raise-argument-error 'eval-expr "CEGIS expr" e)]))

;; Generator: depth 0 is terminals; depth d adds one operator layer.
;; The result is stably sorted by node count, so synthesize returns the
;; smallest fitting program (ties keep generation order).
(define (gen-exprs depth)
  (define (layer depth)
    (if (= depth 0)
        '(x 0 1)
        (let ([subs (layer (- depth 1))])
          (append '(x 0 1)
                  (for*/list ([a subs] [b subs]) `(+ ,a ,b))
                  (for*/list ([a subs] [b subs]) `(* ,a ,b))))))
  (sort (layer depth) < #:key ast-size #:cache-keys? #t))

(define (synthesize examples depth)
  (findf (lambda (e) (andmap (lambda (ex) (= (eval-expr e (car ex)) (cdr ex))) examples))
         (gen-exprs depth)))

;; The specification the verifier checks, and the inputs it checks it on.
;; Verification is bounded: a real verifier would prove it for all x.
(define default-spec (lambda (x) (* 2 x)))
(define default-domain '(0 1 2 3 4 5))

;; Returns the first input where candidate disagrees with spec, or #f
(define (verify candidate [spec default-spec] [domain default-domain])
  (for/first ([x domain] #:unless (= (eval-expr candidate x) (spec x)))
    x))

;; CEGIS loop; #f => failed. Runs at most max-rounds synthesis rounds.
;; Traces print only when #:trace?, so tests and library use stay quiet.
(define (cegis max-rounds
               #:spec [spec default-spec]
               #:domain [domain default-domain]
               #:seed [seed (list (cons (first domain) (spec (first domain))))]
               #:trace? [trace? #f])
  (let loop ([examples seed] [round 1])
    (cond
      [(> round max-rounds) (when trace? (displayln "Round limit reached.")) #f]
      [else
       (when trace? (displayln (format "--- Round ~a ---" round)))
       (when trace? (displayln (format "Examples so far: ~a" examples)))
       (define candidate (synthesize examples 2))
       (when trace? (displayln (format "Candidate: ~a" candidate)))
       (define cex (and candidate (verify candidate spec domain)))
       (cond
         [(not candidate) (when trace? (displayln "No candidate fits current examples.")) #f]
         [(not cex) (when trace? (displayln "Verifier: no counter-example found. CORRECT.")) candidate]
         [else
          (when trace? (displayln (format "Verifier: counter-example input x = ~a" cex)))
          (loop (append examples (list (cons cex (spec cex)))) (+ round 1))])])))

(module+ main
  (displayln "=== Counter-Example Guided Inductive Synthesis ===")
  (newline)
  (displayln "Specification: f(x) = 2*x for x in 0..5")
  (displayln "Grammar: x, 0, 1, (+ e e), (* e e)")
  (displayln "Candidates are ordered by size, so the smallest fitting program wins.")
  (newline)
  (define result (cegis 10 #:trace? #t))
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
  (check-not-false (cegis 10))
  ;; smallest fitting program wins, not a padded variant like (+ 0 (* x x))
  (check-equal? (synthesize '((0 . 0) (1 . 1) (2 . 4) (3 . 9)) 2) '(* x x))
  (check-equal? (cegis 10 #:spec (lambda (x) (* x x))) '(* x x))
  ;; max-rounds bounds the number of synthesis rounds exactly: x^2 needs
  ;; three (candidates x, then (+ x x) which fits (2 . 4), then (* x x))
  (check-false (cegis 2 #:spec (lambda (x) (* x x))))
  (check-equal? (cegis 3 #:spec (lambda (x) (* x x))) '(* x x)))
