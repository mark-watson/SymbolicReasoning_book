#lang racket

;;; NeurASP: mock neural perception + ASP rules as soft Reichenbach implications

(require "../utils/math.rkt"
         "../utils/logic.rkt")

(provide sigmoid dot
         nn-scores
         rule-sat total-satisfaction
         prob-of-flag hash-from-weights compute-sat
         init-weights img)

(define (nn-scores img ws)
  (map (lambda (w) (sigmoid (dot img w))) ws))

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

(define img '(0.9 0.1 0.1 0.1))

;; Slightly stronger initial red/circle signal so ascent improves P(flag)
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
  (hash 'red    (list-ref ps 0)
        'blue   (list-ref ps 1)
        'circle (list-ref ps 2)
        'square (list-ref ps 3)
        'flag   (prob-of-flag (hash 'red (list-ref ps 0)
                                    'blue (list-ref ps 1)
                                    'circle (list-ref ps 2)
                                    'square (list-ref ps 3)))))

(define (compute-sat ws) (total-satisfaction (hash-from-weights ws)))

(define (grad-coord ws i j h)
  (define ws+ (list-set ws i (list-set (list-ref ws i) j (+ (list-ref (list-ref ws i) j) h))))
  (define ws- (list-set ws i (list-set (list-ref ws i) j (- (list-ref (list-ref ws i) j) h))))
  (/ (- (compute-sat ws+) (compute-sat ws-)) (* 2 h)))

(define (train steps lr)
  (let loop ([ws init-weights] [k 0])
    (if (= k steps) ws
        (let ([new-ws
               (for/list ([i (in-range (length ws))])
                 (for/list ([j (in-range (length (list-ref ws i)))])
                   (+ (list-ref (list-ref ws i) j) (* lr (grad-coord ws i j 1e-3)))) )])
          (loop new-ws (+ k 1))))))

(module+ main
  (define final-ws (train 50 0.05))
  (define initial-sat (compute-sat init-weights))
  (define final-sat   (compute-sat final-ws))
  (displayln "NeurASP toy (satisfaction is toy objective, P(flag) is the signal):")
  (displayln (format "  Initial ASP satisfaction: ~a" (exact->inexact initial-sat)))
  (displayln (format "  Satisfaction after 50 steps: ~a" (exact->inexact final-sat)))
  (define probs0 (hash-from-weights init-weights))
  (define probs1 (hash-from-weights final-ws))
  (displayln (format "  P(flag) initial: ~a" (exact->inexact (hash-ref probs0 'flag))))
  (displayln (format "  P(flag) final  : ~a" (exact->inexact (hash-ref probs1 'flag))))
  (displayln "  Note: toy ASP satisfaction mixes four implications; P(flag)")
  (displayln "  is the direct read-out of the learned perception."))

(module+ test
  (require rackunit)
  (check-true (> (hash-ref (hash-from-weights init-weights) 'red) 0.5))
  (check-true (> (compute-sat init-weights) 0))
  (check-not-false (train 5 0.05)))
