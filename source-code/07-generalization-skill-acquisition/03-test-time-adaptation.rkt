#lang racket

;;; Test-Time Adaptation: synthesize a*x+b on the fly as stream arrives

(provide domain f synthesize-on-the-fly online-synthesis)

(define domain '(0 1 2 3 -1 -2 -3))
(define (f a b x) (+ (* a x) b))

(define (synthesize-on-the-fly examples)
  (for*/first ([a domain] [b domain]
               #:when (andmap (lambda (ex) (= (f a b (car ex)) (cdr ex))) examples))
    (list a b)))

(define (online-synthesis stream)
  (let loop ([examples '()] [rest stream] [step 1])
    (if (null? rest)
        (begin
          (displayln (format "Final model after ~a examples: ~a" (length examples) examples))
          (void))
        (let* ([pair (car rest)]
               [examples* (append examples (list pair))]
               [model (synthesize-on-the-fly examples*)])
          (displayln (format "Step ~a: seen ~a, synthesized f(x)=~a*x+~a" step pair (first model) (second model)))
          (loop examples* (cdr rest) (+ step 1))))))

(module+ main
  (displayln "=== Test-Time Adaptation ===")
  (define stream '((0 . 1) (1 . 3) (2 . 5)))
  (online-synthesis stream)
  (newline)
  (displayln "Each new observation triggers synthesis; the symbolic model")
  (displayln "applies immediately to unseen inputs without retraining.")
  (displayln (format "Final model predicts f(4)=~a"
                     (let ([model (synthesize-on-the-fly '((0 . 1) (1 . 3) (2 . 5)))])
                       (f (first model) (second model) 4)))))

(module+ test
  (require rackunit)
  (check-equal? (synthesize-on-the-fly '((0 . 1) (1 . 3) (2 . 5))) '(2 1))
  (check-equal? (synthesize-on-the-fly '((0 . 1))) '(0 1)))
