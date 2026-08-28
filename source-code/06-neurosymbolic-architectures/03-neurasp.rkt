#lang racket

;;; NeurASP: a tiny simulation of the NeurASP architecture
;;;
;;; NeurASP couples neural perception with Answer Set Programming (ASP).
;;;
;;; 1) Neural networks act as oracles: produce probabilities for atomic facts
;;; 2) These probabilities are embedded into an ASP program as soft constraints
;;; 3) The ASP solver finds stable models that satisfy the rules
;;; 4) Training objective: maximize probability that the correct answer
;;;    set contains the target; backpropagating through ASP updates the NN.
;;;
;;; To keep this self-contained we simulate a tiny ASP semantics: rules are
;;; implications, and we approximate the "stable model" objective by a
;;; product of (probabilistic) satisfactions over the rules.  The point is
;;; to expose the architecture, not to reproduce clingo.

;; ---------- sigmoid ----------
(define (sigmoid x) (/ 1.0 (+ 1.0 (exp (- x)))))
(define (dot xs ys) (apply + (map * xs ys)))

;; ---------- mock neural net ----------
;; Input: a feature vector (a small list of numbers describing an image)
;; Output: probability of each atom 'color(red)', 'color(blue)', ...
(define (nn-scores img ws)
  (map (lambda (w) (sigmoid (dot img w))) ws))

;; ---------- ASP rules as soft clauses ----------
;; Represent each rule as a function (probs dict) -> satisfaction.
;; We use a simple implication pattern:
;;    color(red) AND shape(circle)  -> class(flag)
(define (rule-sat probs)
  (let* ((c-red  (hash-ref probs 'red))
         (c-blue (hash-ref probs 'blue))
         (s-circ (hash-ref probs 'circle))
         (s-sq   (hash-ref probs 'square))
         (c-flag (hash-ref probs 'flag))
         ;; Reichenbach implication
         (impl (lambda (x y) (+ 1.0 (- x) (* x y)))))
    (list
     (impl (* c-red s-circ) c-flag)      ;; red & circle -> flag
     (impl (* c-blue s-sq)   c-flag)     ;; blue & square -> flag
     (impl (* c-red s-sq)   (- 1.0 c-flag)) ;; red & square -> NOT flag
     (impl (* c-blue s-circ) (- 1.0 c-flag)))))

;; total satisfaction of all rules
(define (total-satisfaction probs)
  (apply * (rule-sat probs)))

;; ---------- example input ----------
;; Image: red circle
(define img '(0.9 0.1 0.1 0.1))

;; Initial weights (random-ish, 4 output atoms: red,blue,circle,square,flag)
;; We'll hand-set them so that the NN initially recognizes red & circle
;; with moderate confidence.
(define init-weights
  '((2.0 -2.0  0.0  0.0)   ;; red
    (-2.0 2.0  0.0  0.0)   ;; blue
    (0.0  0.0  2.0 -2.0)   ;; circle
    (0.0  0.0 -2.0  2.0))) ;; square

;; The flag atom is derived from ASP, not directly predicted by the net.

;; ---------- helper: compute probability of flag from ASP ----------
(define (prob-of-flag probs)
  ;; flag is true exactly when (red&circle) or (blue&square).
  (let ((red (hash-ref probs 'red))
        (blue (hash-ref probs 'blue))
        (circle (hash-ref probs 'circle))
        (square (hash-ref probs 'square)))
    (max (* red circle) (* blue square))))

;; ---------- training ----------
;; Goal: for img = 'red circle', maximize P(flag)=1 (since red & circle
;; should classify as flag under the rules).

(define (hash-from-weights ws)
  ;; produce a hash with probabilities for the atoms
  (let ((ps (nn-scores img ws)))
    (hash 'red    (list-ref ps 0)
          'blue   (list-ref ps 1)
          'circle (list-ref ps 2)
          'square (list-ref ps 3)
          'flag   (prob-of-flag (hash 'red (list-ref ps 0)
                                      'blue (list-ref ps 1)
                                      'circle (list-ref ps 2)
                                      'square (list-ref ps 3))))))

;; Satisfaction of the ASP program depends on P(flag) which in turn
;; depends on the NN output, so gradient ascent on total-satisfaction
;; adjusts the NN weights to sharpen the required perceptions.

(define (compute-sat ws)
  (total-satisfaction (hash-from-weights ws)))

;; finite-difference gradient wrt a single weight matrix entry
(define (grad-coord ws i j h)
  (let* ((wi (list-ref ws i))
         (wi+ (list-set wi j (+ (list-ref wi j) h)))
         (wi- (list-set wi j (- (list-ref wi j) h)))
         (ws+ (list-set ws i wi+))
         (ws- (list-set ws i wi-))
         (s+ (compute-sat ws+))
         (s- (compute-sat ws-)))
    (/ (- s+ s-) (* 2 h))))

(define (train steps lr)
  (let loop ((ws init-weights) (k 0))
    (if (= k steps)
        ws
        (let ((new-ws
               (for/list ((i (in-range (length ws))))
                 (for/list ((j (in-range (length (list-ref ws i)))))
                   (define g 0.0)
                   ;; gradient of satisfaction wrt ws[i][j]
                   (set! g (grad-coord ws i j 1e-3))
                   (+ (list-ref (list-ref ws i) j) (* lr g))))))
          (loop new-ws (+ k 1))))))

(define final-ws (train 50 0.05))
(define initial-sat (compute-sat init-weights))
(define final-sat   (compute-sat final-ws))

(displayln "NeurASP toy:")
(displayln (format "  Initial ASP satisfaction: ~a" (exact->inexact initial-sat)))
(displayln (format "  Satisfaction after 50 ascent steps: ~a" (exact->inexact final-sat)))
(let ((probs0 (hash-from-weights init-weights))
      (probs1 (hash-from-weights final-ws)))
  (displayln (format "  P(flag) initial: ~a" (exact->inexact (hash-ref probs0 'flag))))
  (displayln (format "  P(flag) final  : ~a" (exact->inexact (hash-ref probs1 'flag)))))
