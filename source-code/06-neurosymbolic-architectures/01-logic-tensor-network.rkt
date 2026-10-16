#lang racket

;;; Logic Tensor Network (LTN)
;;; Constants are embeddings, predicates are sigmoid(dot(weights, concat(args))).

(require "../utils/math.rkt"
         "../utils/logic.rkt")

(provide const const-name const-embedding
         pred pred-name pred-weights
         eval-const eval-pred
         rule-satisfaction kb-satisfaction
         numeric-grad step!)

(struct const (name embedding) #:transparent)
(struct pred (name [weights #:mutable]) #:transparent)

(define (eval-const c) (const-embedding c))

(define (eval-pred p args)
  (define embs (apply append (map eval-const args)))
  (unless (= (length embs) (length (pred-weights p)))
    (raise-argument-error 'eval-pred
                          (format "weights length ~a vs embedding length ~a"
                                  (length (pred-weights p)) (length embs))
                          0 p args))
  (sigmoid (dot (pred-weights p) embs)))

;; Domain: three persons, 2-d embeddings
(define alice (const 'alice '(0.9 0.1)))
(define bob   (const 'bob   '(0.7 0.6)))
(define carol (const 'carol '(0.4 0.8)))

(define friend       (pred 'friend       '(1.0 0.5 1.0 0.5)))
(define likes-sports (pred 'likes-sports '(0.6 0.6)))

(define (rule-satisfaction x y)
  (t-impl (t-and (eval-pred friend (list x y))
                 (eval-pred likes-sports (list x)))
          (eval-pred likes-sports (list y))))

(define (kb-satisfaction)
  (t-and-list
   (for*/list ([x (list alice bob carol)]
               [y (list alice bob carol)])
     (rule-satisfaction x y))))

(define lr 0.05)
(define h  1e-3)

(define (numeric-grad p)
  (define orig (pred-weights p))
  (for/list ([i (in-range (length orig))])
    (define w+ (list-set orig i (+ (list-ref orig i) h)))
    (define w- (list-set orig i (- (list-ref orig i) h)))
    (set-pred-weights! p w+)
    (define sat+ (kb-satisfaction))
    (set-pred-weights! p w-)
    (define sat- (kb-satisfaction))
    (set-pred-weights! p orig)
    (/ (- sat+ sat-) (* 2 h))))

(define (step!)
  (for ([p (list friend likes-sports)])
    (define g (numeric-grad p))
    (set-pred-weights! p (map + (pred-weights p) (map (lambda (x) (* lr x)) g)))))

(module+ main
  (define initial-sat (kb-satisfaction))
  (for ([_ (in-range 100)]) (step!))
  (define final-sat (kb-satisfaction))
  (displayln "Logic Tensor Network (toy):")
  (displayln (format "  Initial KB satisfaction: ~a" (exact->inexact initial-sat)))
  (displayln (format "  After 100 ascent steps:  ~a" (exact->inexact final-sat)))
  (displayln (format "  Final friend weights:       ~a" (pred-weights friend)))
  (displayln (format "  Final likes-sports weights: ~a" (pred-weights likes-sports))))

(module+ test
  (require rackunit)
  ;; ascent must raise KB satisfaction (step! mutates the module's predicates)
  (let ([before (kb-satisfaction)])
    (for ([_ (in-range 10)]) (step!))
    (check-true (> (kb-satisfaction) before)))
  (check-not-exn (lambda () (eval-pred friend (list alice bob))))
  (check-exn exn:fail? (lambda () (eval-pred (pred 'bad '(1.0)) (list alice bob)))))
