#lang racket

;;; Genetic Programming for Program Synthesis (with variable x)

(require racket/match)

(provide eval-expr
         fitness
         random-program
         random-ref
         mutate
         crossover
         evolve)

;; Evaluator with variable x via hash
(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [(? symbol? s) (hash-ref env s (lambda () (error 'eval-expr "unbound variable ~a" s)))]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]
    [_ (raise-argument-error 'eval-expr "arith expr" expr)]))

(define (fitness program examples)
  (define err
    (for/sum ([ex examples])
      (match-define (list input output) ex)
      (abs (- (eval-expr program (hash 'x input)) output))))
  (- err))

(define (random-ref lst)
  (list-ref lst (random (length lst))))

(define (random-program depth)
  (if (= depth 0)
      (if (< (random) 0.5) (random 6) 'x)
      (let ([op (random-ref '(+ * -))]
            [left (random-program (- depth 1))]
            [right (random-program (- depth 1))])
        (list op left right))))

;; Subtree helpers for proper mutation/crossover
(define (subtrees prog)
  (cons prog
        (if (list? prog) (append (subtrees (cadr prog)) (subtrees (caddr prog))) '())))

(define (replace-random-subtree prog new-sub)
  (if (or (not (list? prog)) (= (random 3) 0))
      new-sub
      (if (= (random 2) 0)
          (list (car prog) (replace-random-subtree (cadr prog) new-sub) (caddr prog))
          (list (car prog) (cadr prog) (replace-random-subtree (caddr prog) new-sub)))))

(define (mutate prog)
  (replace-random-subtree prog (random-program 1)))

(define (crossover p1 p2)
  (if (and (list? p1) (list? p2))
      (replace-random-subtree p1 (random-ref (subtrees p2)))
      (random-ref (list p1 p2))))

(define (evolve population examples generations #:trace? [trace? #f])
  (let loop ([gen 0] [pop population])
    (if (>= gen generations)
        (argmax (lambda (p) (fitness p examples)) pop)
        (let* ([scored (sort pop > #:key (lambda (p) (fitness p examples))
                             #:cache-keys? #t)]
               [best (car scored)])
          (when trace?
            (displayln (format "Gen ~a: Best fitness = ~a prog ~a" gen (fitness best examples) best)))
          ;; Selection: keep top half, breed offspring via crossover+mutate
          (define parents (take scored (max 2 (quotient (length scored) 2))))
          (define offspring
            (for/list ([_ (in-range (length parents))])
              (mutate (crossover (random-ref parents) (random-ref parents)))))
          (loop (+ gen 1) (append parents offspring))))))

(module+ main
  ;; Fixed seed so the demo transcript is reproducible run to run
  (random-seed 3)
  (displayln "=== Genetic Programming Example ===")

  (define examples '((0 0) (1 2) (2 4) (3 6)))
  (displayln "Target: f(x)=2x  examples f(0)=0 f(1)=2 f(2)=4 f(3)=6")
  (displayln "")

  (define population
    (for/list ([_ (in-range 20)]) (random-program 2)))

  (displayln "Initial random programs (sample 5):")
  (displayln (take population 5))

  (define best (evolve population examples 5 #:trace? #t))
  (displayln "")
  (displayln (format "Best program after 5 generations: ~a" best))
  (displayln (format "Fitness: ~a" (fitness best examples)))
  (displayln (format "Check: ~a" (map (lambda (x) (eval-expr best (hash 'x x))) '(0 1 2 3))))
  (displayln "Mutation now replaces a random subtree; crossover swaps subtrees."))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(+ x 1) (hash 'x 2)) 3)
  (check-equal? (fitness '(+ x x) '((0 0) (1 2) (2 4))) 0)
  (check-exn exn:fail? (lambda () (eval-expr '(+ y 1) (hash 'x 2))))
  ;; mutation and crossover always yield programs the evaluator accepts
  (for ([_ (in-range 50)])
    (check-pred number? (eval-expr (mutate '(+ x 1)) (hash 'x 3)))
    (check-pred number? (eval-expr (crossover '(+ x 2) '(* 3 (- x 4))) (hash 'x 3)))))
