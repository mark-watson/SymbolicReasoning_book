#lang racket

;;; Automated Hypothesis Generation: enumerate laws, rank by fit + simplicity

(provide eval-expr size dedupe gen-hypotheses fit-error score measurements)

(require racket/match)

(define (eval-expr e i)
  (match e
    ['i i]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a i) (eval-expr b i))]
    [`(- ,a ,b) (- (eval-expr a i) (eval-expr b i))]
    [`(* ,a ,b) (* (eval-expr a i) (eval-expr b i))]
    [`(/ ,a ,b) (let ([d (eval-expr b i)]) (if (zero? d) +inf.0 (/ (eval-expr a i) d)))]
    [`(sq ,a) (let ([v (eval-expr a i)]) (* v v))]
    [_ (raise-argument-error 'eval-expr "hypothesis expr" e)]))

(define (size e)
  (match e
    [(or 'i (? number?)) 1]
    [`(sq ,a) (+ 1 (size a))]
    [`(,(or '+ '- '* '/) ,a ,b) (+ 1 (size a) (size b))]
    [_ 1]))

(define (dedupe xs) (remove-duplicates xs equal?))

(define (gen-hypotheses depth)
  (define leaves '(i 1 2 3 4))
  (if (= depth 1) leaves
      (let ([smaller (gen-hypotheses (- depth 1))])
        (dedupe
         (append leaves
                 (for/list ([a smaller]) `(sq ,a))
                 (for*/list ([a leaves] [b leaves]) `(* ,a ,b))
                 (for*/list ([a smaller] [b leaves]) `(* ,a ,b))
                 (for*/list ([a smaller] [b leaves]) `(+ ,a ,b))
                 (for*/list ([a smaller] [b leaves]) `(/ ,a ,b)))))))

(define (fit-error e data)
  (apply + (map (lambda (pair) (let ([d (- (eval-expr e (car pair)) (cdr pair))]) (* d d))) data)))

(define (score e data [lambda-simple 0.5])
  (+ (fit-error e data) (* lambda-simple (size e))))

(define measurements '((1 . 2.05) (2 . 3.97) (3 . 6.10) (4 . 7.92) (5 . 10.05)))

(module+ main
  (displayln "=== Hypothesis Generation ===")
  (displayln (format "Measurements (I . V): ~a" measurements))
  (define candidates (gen-hypotheses 2))
  (define ranked (sort (map (lambda (e) (cons e (score e measurements))) candidates)
                       < #:key cdr))
  (displayln (format "Number of hypotheses enumerated (deduped): ~a" (length ranked)))
  (newline)
  (displayln "Top 5 hypotheses by fit + simplicity:")
  (for ([p (take ranked 5)])
    (displayln (format "  ~a   score=~a  size=~a" (car p) (exact->inexact (cdr p)) (size (car p)))))
  (newline)
  (define best (car (first ranked)))
  (displayln (format "Selected hypothesis: V = ~a" best))
  (displayln "This is Ohm's law V = 2*I. Duplicate forms like (+ i i) and (* i 2)")
  (displayln "are semantically equal; a normalize pass would merge them."))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(* i 2) 3) 6)
  (check-equal? (eval-expr '(sq i) 3) 9)
  (check-equal? (size '(* i 2)) 3)
  (check-true (< (fit-error '(* i 2) measurements) (fit-error '(+ i 3) measurements))))
