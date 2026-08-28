#lang racket

;;; Differentiable Inductive Logic Programming (∂ILP)
;;;
;;; ∂ILP makes ILP differentiable by relaxing clause selection into a
;;; learnable softmax over candidate rules.  We demonstrate with a tiny
;;; learning task: given positive and negative examples of "grandparent",
;;; pick the best rule from a small candidate set.
;;;
;;; Candidate rules (2-step chains):
;;;   R1: parent(X,Y) ∧ parent(Y,Z) -> grandparent(X,Z)
;;;   R2: parent(X,Y) ∧ sibling(Y,Z) -> grandparent(X,Z)
;;;   R3: sibling(X,Y) ∧ parent(Y,Z) -> grandparent(X,Z)
;;;
;;; We learn the rule weights by gradient descent on a loss that
;;; penalizes low scores on positives and high scores on negatives.

;; ---------- candidate rule evaluation over a relation DB ----------
;; Relations are represented as sets of (a . b) pairs.
(struct db (parent sibling) #:transparent)

;; test whether relation r holds for pair (x,y)
(define (holds? db rel x y)
  (member (cons x y) (case rel
                       [(parent) (db-parent db)]
                       [(sibling) (db-sibling db)])))

;; Each rule is a function from (db,x,z) to a "match" value in [0,1].
;; Because relations are crisp here, matches are 0 or 1; the
;; differentiation is done at the level of rule weights, not the
;; relations themselves.

(define (eval-rule r db x z)
  (cond
    [(eq? r 'R1)
     (if (for/or ((y '(ann bob carl dan)))
           (and (holds? db 'parent x y)
                (holds? db 'parent y z)))
         1.0 0.0)]
    [(eq? r 'R2)
     (if (for/or ((y '(ann bob carl dan)))
           (and (holds? db 'parent x y)
                (holds? db 'sibling y z)))
         1.0 0.0)]
    [(eq? r 'R3)
     (if (for/or ((y '(ann bob carl dan)))
           (and (holds? db 'sibling x y)
                (holds? db 'parent y z)))
         1.0 0.0)]))

;; ---------- weighted inference ----------
;; Given rule weights, compute a soft inference on whether the pair
;; (x,z) satisfies grandparent.
(define (rule-weights->scores weights db x z)
  (for/list ((r '(R1 R2 R3)))
    (eval-rule r db x z)))

(define (infer-grandparent weights db x z)
  (let* ((scores (rule-weights->scores weights db x z))
         ;; softmax-weighted sum of rule scores
         (exps (map (lambda (w) (exp w)) weights))
         (sumexps (apply + exps))
         (softweights (map (lambda (e) (/ e sumexps)) exps)))
    (apply + (map * softweights scores))))

;; ---------- dataset ----------
;; Family tree:
;;   ann -> bob -> dan        (parent chain)
;;   bob sibling carl
;; So ann is grandparent of dan.
(define the-db
  (db '((ann . bob) (bob . dan))
      '((bob . carl) (carl . bob))))

;; positive and negative examples  (ann,dan) is true; (ann,carl) false.
(define positives '((ann . dan)))
(define negatives '((ann . carl)))

;; ---------- loss and training ----------
;; Loss = mean squared error between infergrandparent and target
(define (loss weights)
  (let loop ((pos positives) (acc 0.0))
    (if (null? pos)
        (let loop2 ((neg negatives) (acc2 acc))
          (if (null? neg)
              acc2
              (let* ((x (caar neg)) (z (cdar neg))
                     (pred (infer-grandparent weights the-db x z)))
                (loop2 (cdr neg) (+ acc2 (* pred pred))))))
        (let* ((x (caar pos)) (z (cdar pos))
               (pred (infer-grandparent weights the-db x z)))
          (loop (cdr pos) (+ acc (* (- 1.0 pred) (- 1.0 pred))))))))

;; finite-difference gradient wrt each weight
(define (grad weights h)
  (define n (length weights))
  (define orig-loss (loss weights))
  (for/list ((i (in-range n)))
    (let* ((wi  (list-ref weights i))
           (w+  (list-set weights i (+ wi h)))
           (w-  (list-set weights i (- wi h)))
           (l+ (loss w+))
           (l- (loss w-)))
      (/ (- l+ l-) (* 2 h)))))

;; gradient descent
(define (learn steps lr)
  (let loop ((w '(0.0 0.0 0.0)) (step 0))
    (if (= step steps)
        w
        (let ((g (grad w 1e-3)))
          (loop (map - w (map (lambda (x) (* lr x)) g))
                (+ step 1))))))

;; ---------- run ----------
(define init-weights '(0.0 0.0 0.0))
(define trained (learn 100 0.2))

;; final softmax for inspection
(define (softmax ws)
  (let* ((exps (map exp ws))
         (sum (apply + exps)))
    (map (lambda (e) (/ e sum)) exps)))

(displayln "Differentiable ILP (toy):")
(displayln (format "  Initial loss: ~a" (exact->inexact (loss init-weights))))
(displayln (format "  Final loss:   ~a" (exact->inexact (loss trained))))
(displayln (format "  Final weights: ~a" trained))
(displayln (format "  Softmax over rules [R1,R2,R3]: ~a" (map exact->inexact (softmax trained))))
(displayln "  R1 is the correct rule; the model should assign it the largest weight.")
(let* ((probs (softmax trained))
       (p1 (first probs)) (p2 (second probs)) (p3 (third probs)))
  (displayln (format "    R1 prob: ~a" (exact->inexact p1)))
  (displayln (format "    R2 prob: ~a" (exact->inexact p2)))
  (displayln (format "    R3 prob: ~a" (exact->inexact p3)))
  (displayln (format "  Inference on positive (ann,dan): ~a"
                     (exact->inexact (infer-grandparent trained the-db 'ann 'dan))))
  (displayln (format "  Inference on negative (ann,carl): ~a"
                     (exact->inexact (infer-grandparent trained the-db 'ann 'carl)))))
