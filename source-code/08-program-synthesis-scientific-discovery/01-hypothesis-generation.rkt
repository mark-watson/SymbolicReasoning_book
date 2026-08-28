#lang racket

;;; Automated Hypothesis Generation and Testing
;;;
;;; A scientific hypothesis is an executable program whose predictions
;;; match experimental data.  Given measurements of a physical system,
;;; we enumerate candidate laws from a grammar of arithmetic formulas
;;; and score each by fit to data with a simplicity penalty (Occam's
;;; razor).  The top-ranked hypothesis is returned as the "theory".
;;;
;;; The domain: an experimenter has measurements of a resistor circuit
;;; relating voltage V and current I.  Ohm's law  V = R*I  should be
;;; rediscovered by searching over hypotheses of the form V = f(I).

;; ---------- tiny expression language ----------
(define (eval-expr e i)
  (match e
    ['i i]
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a i) (eval-expr b i))]
    [`(- ,a ,b) (- (eval-expr a i) (eval-expr b i))]
    [`(* ,a ,b) (* (eval-expr a i) (eval-expr b i))]
    [`(/ ,a ,b) (let ((d (eval-expr b i)))
                  (if (zero? d) +inf.0 (/ (eval-expr a i) d)))]
    [`(sq ,a)   (let ((v (eval-expr a i))) (* v v))]
    [_ (error 'eval-expr "bad expr: ~a" e)]))

;; size = number of nodes in the AST; used as a simplicity penalty
(define (size e)
  (match e
    [(or ' i (? number?)) 1]
    [`(sq ,a) (+ 1 (size a))]
    [`(,(or '+ '- '* '/) ,a ,b) (+ 1 (size a) (size b))]
    [_ 999]))

;; ---------- hypothesis enumeration ----------
;; We enumerate candidate hypotheses of increasing depth, deduplicating
;; syntactically identical trees.
(define (dedupe xs)
  (remove-duplicates xs equal?))

(define (gen-hypotheses depth)
  (define leaves '(i 1 2 3 4))
  (if (= depth 1)
      leaves
      (let ((smaller (gen-hypotheses (- depth 1))))
        (dedupe
         (append
          leaves
          (for/list ((a smaller)) `(sq ,a))
          ;; only combine leaves with leaves and unary results with leaves
          ;; to keep the search space bounded
          (for*/list ((a leaves) (b leaves)) `(* ,a ,b))
          (for*/list ((a smaller) (b leaves)) `(* ,a ,b))
          (for*/list ((a smaller) (b leaves)) `(+ ,a ,b))
          (for*/list ((a smaller) (b leaves)) `(/ ,a ,b)))))))

;; ---------- scoring ----------
;; data is a list of (i . v) pairs; fit = sum squared error
(define (fit-error e data)
  (apply +
         (map (lambda (pair)
                (let* ((x (car pair)) (y (cdr pair))
                       (pred (eval-expr e x))
                       (d (- pred y)))
                  (* d d)))
              data)))

;; score balances fit and simplicity; lower is better
(define (score e data (lambda-simple 0.5))
  (+ (fit-error e data) (* lambda-simple (size e))))

;; ---------- the experimental data ----------
;; Simulated resistor circuit: V = 2 * I, with small measurement noise.
(define measurements
  '((1 . 2.05) (2 . 3.97) (3 . 6.10) (4 . 7.92) (5 . 10.05)))

;; ---------- run ----------
(displayln "=== Hypothesis Generation ===")
(displayln (format "Measurements (I . V): ~a" measurements))

(define candidates (gen-hypotheses 2))

;; rank candidates by score
(define ranked
  (sort (map (lambda (e) (cons e (score e measurements)))
             candidates)
        (lambda (p1 p2) (< (cdr p1) (cdr p2)))))

(displayln (format "Number of hypotheses enumerated: ~a" (length ranked)))
(newline)
(displayln "Top 5 hypotheses by fit + simplicity:")
(for ((p (take ranked 5)))
  (displayln (format "  ~a   score=~a  size=~a"
                     (car p) (exact->inexact (cdr p)) (size (car p)))))

(newline)
(define best (car (first ranked)))
(displayln (format "Selected hypothesis: V = ~a" best))
(displayln "In Ohm's-law units, this is V = 2*I.")
