#lang racket

;;; Logic Tensor Network (LTN)
;;;
;;; An LTN bridges first-order logic and (deep) neural networks:
;;;   * constants are embedding vectors
;;;   * predicates are functions from tuples of constants to [0,1]
;;;   * logical connectives are differentiable t-norms
;;;   * universal quantification is generalized product (t-norm over a list)
;;;
;;; Domain: friends who influence each other
;;;     forall x,y. (friend(x,y) AND likes(x,sports)) -> likes(y,sports)
;;; We evaluate the rule's satisfaction before and after a short
;;; gradient-ascent training loop that adjusts the predicate weights.

;; ---------- math helpers ----------
(define (dot xs ys) (apply + (map * xs ys)))
(define (sigmoid x) (/ 1.0 (+ 1.0 (exp (- x)))))

;; product t-norm for conjunction
(define (t-and x y) (* x y))
(define (t-and-list xs) (apply * xs))

;; fuzzy negation and Reichenbach implication (smooth)
(define (t-not x) (- 1.0 x))
(define (t-impl x y) (+ 1.0 (- x) (* x y)))

;; ---------- LTN structures ----------
;; A constant is a fixed embedding vector.
(struct const (name embedding) #:transparent)

;; A predicate's semantics is defined by a weight vector: sigmoid of the
;; dot product against the concatenated argument embeddings.
(struct pred (name [weights #:mutable]) #:transparent)

(define (eval-const c) (const-embedding c))
(define (eval-pred p args)
  (sigmoid (dot (pred-weights p)
                (apply append (map eval-const args)))))

;; ---------- domain ----------
(define alice (const 'alice '(0.9 0.1)))
(define bob   (const 'bob   '(0.7 0.6)))
(define carol (const 'carol '(0.4 0.8)))

(define friend       (pred 'friend       '(1.0 0.5 1.0 0.5)))
(define likes-sports (pred 'likes-sports '(0.6 0.6)))

;; ---------- rule evaluation ----------
;; friend(x,y) AND likes(x,sports) -> likes(y,sports)   (degrees in [0,1])
(define (rule-satisfaction x y)
  (let* ((fxy (eval-pred friend (list x y)))
         (lsx (eval-pred likes-sports (list x)))
         (lsy (eval-pred likes-sports (list y)))
         (premise (t-and fxy lsx)))
    (t-impl premise lsy)))

;; The universal quantifier generalizes the t-norm to all domain pairs.
(define (kb-satisfaction)
  (t-and-list
   (for*/list ((x (list alice bob carol))
               (y (list alice bob carol)))
     (rule-satisfaction x y))))

;; ---------- gradient ascent on predicate weights ----------
(define lr 0.05)
(define h  1e-3)

(define (numeric-grad p)
  (let* ((orig (pred-weights p))
         (len (length orig)))
    (for/list ((i (in-range len)))
      (let* ((wi   (list-ref orig i))
             (w+   (list-set orig i (+ wi h)))
             (w-   (list-set orig i (- wi h))))
        (set-pred-weights! p w+)
        (define sat+ (kb-satisfaction))
        (set-pred-weights! p w-)
        (define sat- (kb-satisfaction))
        (set-pred-weights! p orig)
        (/ (- sat+ sat-) (* 2 h))))))

(define (step!)
  (for ((p (list friend likes-sports)))
    (let ((g (numeric-grad p)))
      (set-pred-weights! p (map + (pred-weights p)
                                (map (lambda (x) (* lr x)) g))))))

;; ---------- run ----------
(define initial-sat (kb-satisfaction))
(for ((_ (in-range 100))) (step!))
(define final-sat (kb-satisfaction))

(displayln "Logic Tensor Network (toy):")
(displayln (format "  Initial KB satisfaction: ~a" (exact->inexact initial-sat)))
(displayln (format "  After 100 ascent steps:  ~a" (exact->inexact final-sat)))
(displayln (format "  Final friend weights:       ~a" (pred-weights friend)))
(displayln (format "  Final likes-sports weights: ~a" (pred-weights likes-sports)))
