#lang racket

;;; NeurASP: mock neural perception + ASP rules as soft Reichenbach
;;; implications, trained end-to-end on one labeled observation.
;;; The objective mirrors NeurASP: rule satisfaction (prior over stable
;;; models) times the data likelihood P(flag = label) for the observation.

(require "../utils/math.rkt"
         "../utils/logic.rkt")

(provide sigmoid dot
         nn-scores
         rule-sat total-satisfaction
         prob-of-flag hash-from-weights objective
         init-weights img flag-label)

(define (nn-scores img ws)
  (map (lambda (w) (sigmoid (dot img w))) ws))

;; ASP rules: red circle or blue square implies flag; mixed combos imply
;; not flag. Each rule is a soft implication returning a score in [0,1].
(define (rule-sat probs)
  (define c-red  (hash-ref probs 'red))
  (define c-blue (hash-ref probs 'blue))
  (define s-circ (hash-ref probs 'circle))
  (define s-sq   (hash-ref probs 'square))
  (define c-flag (hash-ref probs 'flag))
  (list
   (t-impl (* c-red s-circ) c-flag)
   (t-impl (* c-blue s-sq) c-flag)
   (t-impl (* c-red s-sq) (- 1.0 c-flag))
   (t-impl (* c-blue s-circ) (- 1.0 c-flag))))

(define (total-satisfaction probs) (apply * (rule-sat probs)))

;; One observed image: mostly red, some circle. Label: this is a flag.
(define img '(0.9 0.1 0.1 0.1))
(define flag-label 1.0)

;; Strong initial red/circle signal
(define init-weights
  '((2.5 -2.0  0.0  0.0)
    (-2.0 2.0  0.0  0.0)
    (0.0  0.0  2.5 -2.0)
    (0.0  0.0 -2.0  2.0)))

(define (prob-of-flag probs)
  (max (* (hash-ref probs 'red) (hash-ref probs 'circle))
       (* (hash-ref probs 'blue) (hash-ref probs 'square))))

(define (hash-from-weights ws)
  (define ps (nn-scores img ws))
  (define base (hash 'red (list-ref ps 0)
                     'blue (list-ref ps 1)
                     'circle (list-ref ps 2)
                     'square (list-ref ps 3)))
  (hash-set base 'flag (prob-of-flag base)))

;; NeurASP training objective: P(stable model satisfying rules)
;; times P(observed label). Maximizing it teaches the network to raise
;; P(flag) for this red-circle image, since the label is flag=1 and the
;; rules say red circle -> flag. With the label 0, ascent on the same
;; objective would push P(flag) down instead (see exercise in the text).
(define (objective ws)
  (define probs (hash-from-weights ws))
  (define p-flag (hash-ref probs 'flag))
  (* (total-satisfaction probs)
     (if (= flag-label 1.0) p-flag (- 1.0 p-flag))))

(define (grad-coord ws i j h)
  (define ws+ (list-set ws i (list-set (list-ref ws i) j (+ (list-ref (list-ref ws i) j) h))))
  (define ws- (list-set ws i (list-set (list-ref ws i) j (- (list-ref (list-ref ws i) j) h))))
  (/ (- (objective ws+) (objective ws-)) (* 2 h)))

(define (train steps lr)
  (let loop ([ws init-weights] [k 0])
    (if (= k steps) ws
        (let ([new-ws
               (for/list ([i (in-range (length ws))])
                 (for/list ([j (in-range (length (list-ref ws i)))])
                   (+ (list-ref (list-ref ws i) j) (* lr (grad-coord ws i j 1e-3)))))])
          (loop new-ws (+ k 1))))))

(module+ main
  (define final-ws (train 50 0.05))
  (define probs0 (hash-from-weights init-weights))
  (define probs1 (hash-from-weights final-ws))
  (displayln "NeurASP toy: objective = rule satisfaction x P(label):")
  (displayln (format "  Rule satisfaction initial: ~a  final: ~a"
                     (exact->inexact (total-satisfaction probs0))
                     (exact->inexact (total-satisfaction probs1))))
  (displayln (format "  P(flag) initial: ~a" (exact->inexact (hash-ref probs0 'flag))))
  (displayln (format "  P(flag) final  : ~a" (exact->inexact (hash-ref probs1 'flag))))
  (displayln (format "  Objective initial: ~a  final: ~a"
                     (exact->inexact (objective init-weights))
                     (exact->inexact (objective final-ws))))
  (displayln "  The red-circle image is labeled flag=1, and the rules say")
  (displayln "  red circle -> flag, so ascent strengthens the circle neuron")
  (displayln "  and P(flag) rises. Rule satisfaction alone would not pick")
  (displayln "  this direction; the data term is what couples learning to")
  (displayln "  the label, as in NeurASP's P(answer | perception) objective."))

(module+ test
  (require rackunit)
  (check-true (> (hash-ref (hash-from-weights init-weights) 'red) 0.5))
  (check-true (> (total-satisfaction (hash-from-weights init-weights)) 0))
  (check-not-false (train 5 0.05))
  ;; After 50 steps, P(flag) and the objective both increase
  (define trained (train 50 0.05))
  (check-true (> (hash-ref (hash-from-weights trained) 'flag)
                 (hash-ref (hash-from-weights init-weights) 'flag)))
  (check-true (> (objective trained) (objective init-weights))))
