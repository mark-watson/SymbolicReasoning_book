#lang racket

;;; Logical Neural Network (LNN)
;;;
;;; An LNN encodes a logical formula directly in the structure of a
;;; neural network: every neuron computes a logical (sub)formula's truth
;;; value and the connections mirror the formula's parse tree.
;;;
;;; We define three neuron types:
;;;   input  - holds a truth value (a degree in [0,1])
;;;   and    - conjunctive neuron, computes product of inputs
;;;   impl   - implication neuron, computes Reichenbach implication
;;;
;;; A network is then built for the toy theory
;;;     P(x) AND (P(x) -> Q(x))
;;; and we demonstrate both forward evaluation and a tiny learning loop
;;; that adjusts the weight on the implication edge so the system
;;; approaches the classical behavior "if P is true then Q must be true".

;; ---------- neuron struct ----------
(struct neuron (kind [inputs #:mutable] [value #:mutable]) #:transparent)
;; kind: 'input | 'and | 'impl

;; ---------- smooth logical connectives ----------
(define (t-and xs) (apply * xs))
(define (t-impl x y) (+ 1.0 (- x) (* x y)))

;; ---------- evaluation ----------
(define (eval-neuron n)
  (match (neuron-kind n)
    ['input (neuron-value n)]
    ['and
     (let ((vals (map eval-neuron (neuron-inputs n))))
       (set-neuron-value! n (t-and vals))
       (neuron-value n))]
    ['impl
     (let* ((pre  (eval-neuron (first (neuron-inputs n))))
            (post (eval-neuron (second (neuron-inputs n))))
            (res  (t-impl pre post)))
       (set-neuron-value! n res)
       res)]
    [_ (error 'eval-neuron "unknown kind: ~a" (neuron-kind n))]))

;; ---------- gradient (finite differences) ----------
;; With respect to a single input neuron's value.
(define (neuron-grad net target-neuron eps)
  (let* ((orig (neuron-value target-neuron))
         (orig-out (eval-neuron net)))
    (set-neuron-value! target-neuron (min 1.0 (+ orig eps)))
    (define hi (eval-neuron net))
    (set-neuron-value! target-neuron (max 0.0 (- orig eps)))
    (define lo (eval-neuron net))
    (set-neuron-value! target-neuron orig)
    (/ (- hi lo) (* 2 eps))))

;; ---------- build the toy network ----------
;; nodes
(define p (neuron 'input '() 0.9))   ; P(x) true to degree 0.9
(define q (neuron 'input '() 0.2))   ; Q(x) true to degree 0.2

;; implication neuron P -> Q
(define impl-node (neuron 'impl (list p q) #f))

;; overall network: AND of P and (P -> Q)
(define net (neuron 'and (list p impl-node) #f))

;; ---------- forward evaluation ----------
(define initial-out (eval-neuron net))

;; ---------- training: nudge Q upward ----------
;; LNN "learning" here is gradient ascent on the network output w.r.t.
;; the input q.  This illustrates backward/forward interplay: because the
;; implication neuron penalizes states where P=0.9 and Q=0.2, ascending
;; on the overall output increases Q.

(define steps 60)
(define lr 0.25)
(define eps 1e-4)

(for ((_ (in-range steps)))
  (let ((g (neuron-grad net q eps)))
    (set-neuron-value! q (max 0.0 (min 1.0 (+ (neuron-value q) (* lr g)))))))

(define final-out (eval-neuron net))

(displayln "Logical Neural Network (toy):")
(displayln (format "  Initial network output = ~a" (exact->inexact initial-out)))
(displayln (format "  Learned Q after ~a steps = ~a" steps (exact->inexact (neuron-value q))))
(displayln (format "  Final network output   = ~a" (exact->inexact final-out)))
(displayln "  Because P=0.9 and (P->Q) must both be high,")
(displayln "  gradient ascent on the AND pushes Q toward 1.0,")
(displayln "  recovering the classical derivation Q from P and P->Q.")
