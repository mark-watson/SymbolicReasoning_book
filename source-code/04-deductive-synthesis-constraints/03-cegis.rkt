#lang racket

;;; Counter-Example Guided Inductive Synthesis (CEGIS)
;;;
;;; CEGIS alternates between two players:
;;;   1. SYNTHESIZER: propose a program correct on the examples seen so far
;;;   2. VERIFIER:    check the candidate on the full spec; if it fails,
;;;                   return a counter-example input that refutes it
;;; The loop terminates when the verifier finds no counter-example.
;;;
;;; Task: synthesize f(x) over the grammar {x, 0, 1, (+ e e), (* e e), (- e e)}
;;; with the (hidden) specification that f must compute 2*x for all x in 0..5.

;; ---------- tiny expression interpreter ----------
(define (eval-expr e x)
  (match e
    ['x x]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a x) (eval-expr b x))]
    [`(* ,a ,b) (* (eval-expr a x) (eval-expr b x))]
    [`(- ,a ,b) (- (eval-expr a x) (eval-expr b x))]))

;; ---------- candidate generator ----------
;; All expressions up to a given depth, with pruning of trivially
;; equivalent shapes kept minimal for clarity.
(define (gen-exprs depth)
  (if (= depth 0)
      '(x 0 1)
      (let ((subs (gen-exprs (- depth 1))))
        (append '(x 0 1)
                (for*/list ((a subs) (b subs))
                  `(+ ,a ,b))
                (for*/list ((a subs) (b subs))
                  `(* ,a ,b))))))

;; ---------- synthesizer ----------
;; First candidate (in generation order) that fits every known example.
(define (synthesize examples depth)
  (findf (lambda (e)
           (andmap (lambda (ex) (= (eval-expr e (car ex)) (cdr ex)))
                   examples))
         (gen-exprs depth)))

;; ---------- verifier ----------
;; The full specification: f must equal 2*x on every input in 0..5.
;; Returns a counter-example input, or #f if the candidate is correct.
(define (verify candidate)
  (define (spec x) (* 2 x))
  (for/first ((x '(0 1 2 3 4 5))
              #:when (not (= (eval-expr candidate x) (spec x))))
    x))

;; ---------- CEGIS loop ----------
(define (cegis max-rounds)
  (let loop ((examples '((0 . 0)))  ; seed with one example
             (round 1))
    (displayln (format "--- Round ~a ---" round))
    (displayln (format "Examples so far: ~a" examples))
    (let ((candidate (synthesize examples 2)))
      (displayln (format "Candidate: ~a" candidate))
      (let ((cex (verify candidate)))
        (cond
          [(not cex)
           (displayln "Verifier: no counter-example found. CORRECT.")
           candidate]
          [(> round max-rounds)
           (displayln "Round limit reached.")
           #f]
          [else
           (displayln (format "Verifier: counter-example input x = ~a" cex))
           (loop (append examples (list (cons cex (* 2 cex))))
                 (+ round 1))])))))

(displayln "=== Counter-Example Guided Inductive Synthesis ===")
(newline)
(displayln "Specification (verified): f(x) = 2*x for x in 0..5")
(displayln "Grammar: x, 0, 1, (+ e e), (* e e)")
(newline)

(define result (cegis 10))

(newline)
(if result
    (begin
      (displayln (format "Final synthesized program: ~a" result))
      (displayln (format "Check: ~a"
                         (map (lambda (x) (eval-expr result x)) '(0 1 2 3 4 5)))))
    (displayln "Synthesis failed within the round limit."))

(newline)
(displayln "Note how few examples were needed: the verifier supplies only")
(displayln "falsifying inputs, so the synthesizer never sees the full spec")
(displayln "as a data table. This is the power of the CEGIS architecture.")
