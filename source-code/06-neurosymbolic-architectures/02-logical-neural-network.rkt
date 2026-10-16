#lang racket

;;; Logical Neural Network (LNN): formula is the network.
;;; P AND (P -> Q), with finite-difference ascent on Q.
;;; Uses the product t-norm and Reichenbach implication for simplicity;
;;; IBM's LNN uses weighted Lukasiewicz logic with upper/lower bounds.

(require "../utils/logic.rkt")

(provide neuron neuron-kind neuron-inputs neuron-value
         eval-neuron neuron-grad)

(struct neuron (kind [inputs #:mutable] [value #:mutable]) #:transparent)

;; Pure evaluation: compute value without mutating non-input nodes until the end
(define (eval-neuron-pure n)
  (match (neuron-kind n)
    ['input (neuron-value n)]
    ['and (t-and-list (map eval-neuron-pure (neuron-inputs n)))]
    ['impl (t-impl (eval-neuron-pure (first (neuron-inputs n)))
                   (eval-neuron-pure (second (neuron-inputs n))))]
    [_ (raise-argument-error 'eval-neuron "known kind" (neuron-kind n))]))

;; Mutable wrapper that caches the result in the node's value
(define (eval-neuron n)
  (define v (eval-neuron-pure n))
  (set-neuron-value! n v)
  v)

(define (neuron-grad net target-neuron eps)
  (define orig (neuron-value target-neuron))
  (set-neuron-value! target-neuron (min 1.0 (+ orig eps)))
  (define hi (eval-neuron-pure net))
  (set-neuron-value! target-neuron (max 0.0 (- orig eps)))
  (define lo (eval-neuron-pure net))
  (set-neuron-value! target-neuron orig)
  (/ (- hi lo) (* 2 eps)))

(module+ main
  (define p (neuron 'input '() 0.9))
  (define q (neuron 'input '() 0.2))
  (define impl-node (neuron 'impl (list p q) #f))
  (define net (neuron 'and (list p impl-node) #f))

  (define initial-out (eval-neuron net))
  (define steps 60)
  (define lr 0.25)
  (define eps 1e-4)

  (for ([_ (in-range steps)])
    (define g (neuron-grad net q eps))
    (set-neuron-value! q (max 0.0 (min 1.0 (+ (neuron-value q) (* lr g))))))

  (define final-out (eval-neuron net))

  (displayln "Logical Neural Network (toy):")
  (displayln (format "  Initial network output = ~a" (exact->inexact initial-out)))
  (displayln (format "  Learned Q after ~a steps = ~a" steps (exact->inexact (neuron-value q))))
  (displayln (format "  Final network output   = ~a" (exact->inexact final-out)))
  (displayln "  Because P=0.9 and (P->Q) must both be high,")
  (displayln "  gradient ascent on the AND pushes Q toward 1.0."))

(module+ test
  (require rackunit)
  (define p (neuron 'input '() 0.9))
  (define q (neuron 'input '() 0.2))
  (define impl (neuron 'impl (list p q) #f))
  (define net (neuron 'and (list p impl) #f))
  (check-= (eval-neuron-pure net) 0.252 0.001)
  (check-true (> (neuron-grad net q 1e-4) 0)))
