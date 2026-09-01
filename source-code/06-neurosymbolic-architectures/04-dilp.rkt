#lang racket

;;; Differentiable Inductive Logic Programming (∂ILP)
;;; Softmax over R1,R2,R3; gradient descent on MSE

(provide db db-parent db-sibling
         holds? eval-rule
         infer-grandparent
         loss grad learn softmax
         the-db positives negatives)

(struct db (parent sibling) #:transparent)

(define (holds? db rel x y)
  (and (member (cons x y)
               (case rel
                 [(parent) (db-parent db)]
                 [(sibling) (db-sibling db)]))
       #t))

(define (eval-rule r db x z)
  (define (chain rel1 rel2)
    (for/or ([y '(ann bob carl dan)])
      (and (holds? db rel1 x y) (holds? db rel2 y z))))
  (case r
    [(R1) (if (chain 'parent 'parent) 1.0 0.0)]
    [(R2) (if (chain 'parent 'sibling) 1.0 0.0)]
    [(R3) (if (chain 'sibling 'parent) 1.0 0.0)]
    [else 0.0]))

(define (softmax ws)
  (define exps (map exp ws))
  (define sum (apply + exps))
  (map (lambda (e) (/ e sum)) exps))

(define (infer-grandparent weights db x z)
  (define scores (for/list ([r '(R1 R2 R3)]) (eval-rule r db x z)))
  (define probs (softmax weights))
  (apply + (map * probs scores)))

(define the-db (db '((ann . bob) (bob . dan)) '((bob . carl) (carl . bob))))
(define positives '((ann . dan)))
(define negatives '((ann . carl)))

(define (loss weights)
  (+ (for/sum ([pr positives])
       (define pred (infer-grandparent weights the-db (car pr) (cdr pr)))
       (* (- 1.0 pred) (- 1.0 pred)))
     (for/sum ([pr negatives])
       (define pred (infer-grandparent weights the-db (car pr) (cdr pr)))
       (* pred pred))))

(define (grad weights h)
  (for/list ([i (in-range (length weights))])
    (/ (- (loss (list-set weights i (+ (list-ref weights i) h)))
          (loss (list-set weights i (- (list-ref weights i) h))))
       (* 2 h))))

(define (learn steps lr)
  (let loop ([w '(0.0 0.0 0.0)] [step 0])
    (if (= step steps) w
        (loop (map - w (map (lambda (x) (* lr x)) (grad w 1e-3))) (+ step 1)))))

(module+ main
  (define init-weights '(0.0 0.0 0.0))
  (define trained (learn 100 0.2))
  (displayln "Differentiable ILP (toy):")
  (displayln (format "  Initial loss: ~a" (exact->inexact (loss init-weights))))
  (displayln (format "  Final loss:   ~a" (exact->inexact (loss trained))))
  (displayln (format "  Final weights: ~a" trained))
  (displayln (format "  Softmax over rules [R1,R2,R3]: ~a" (map exact->inexact (softmax trained))))
  (displayln "  R1 is the correct rule; the model should assign it the largest weight.")
  (define probs (softmax trained))
  (displayln (format "    R1 prob: ~a" (exact->inexact (first probs))))
  (displayln (format "    R2 prob: ~a" (exact->inexact (second probs))))
  (displayln (format "    R3 prob: ~a" (exact->inexact (third probs))))
  (displayln (format "  Inference on positive (ann,dan): ~a" (exact->inexact (infer-grandparent trained the-db 'ann 'dan))))
  (displayln (format "  Inference on negative (ann,carl): ~a" (exact->inexact (infer-grandparent trained the-db 'ann 'carl)))))

(module+ test
  (require rackunit)
  (check-true (holds? the-db 'parent 'ann 'bob))
  (check-false (holds? the-db 'parent 'ann 'dan))
  (check-true (> (first (softmax (learn 100 0.2))) 0.8))
  (check-true (< (loss (learn 100 0.2)) (loss '(0.0 0.0 0.0)))))
