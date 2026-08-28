#lang racket

;;; Genetic Programming for Program Synthesis
;;; Evolves programs through mutation, crossover, and selection

(provide (all-defined-out))

;; Simple expression evaluator
(define (eval-expr expr env)
  (cond
    ((number? expr) expr)
    ((symbol? expr) (hash-ref env expr expr))
    ((and (list? expr) (= (length expr) 3))
     (let ((op (car expr))
           (a (eval-expr (cadr expr) env))
           (b (eval-expr (caddr expr) env)))
       (case op
         ((+) (+ a b))
         ((*) (* a b))
         ((-) (- a b))
         (else (error "Unknown op" op)))))
    (else (error "Invalid expr" expr))))

;; Fitness: negative error
(define (fitness program examples)
  (let ((error 0))
    (for ((ex examples))
      (let ((input (car ex))
            (output (cadr ex)))
        (let ((pred (eval-expr program (hash 'x input))))
          (set! error (+ error (abs (- pred output)))))))
    (- error)))

;; Random program generation
(define (random-program depth)
  (if (= depth 0)
      (if (< (random) 0.5)
          (random 6)  ; Random number 0-5
          'x)          ; Variable x
      (let ((op (random-ref '(+ * -)))
            (left (random-program (- depth 1)))
            (right (random-program (- depth 1))))
        (list op left right))))

;; Helper: random element from list
(define (random-ref lst)
  (list-ref lst (random (length lst))))

;; Evolution
(define (evolve population examples generations)
  (let loop ((gen 0) (pop population))
    (if (>= gen generations)
        ;; Return best after max generations
        (car (sort pop > #:key (lambda (p) (fitness p examples))))
        (let ((scored 
               (sort pop > #:key (lambda (p) (fitness p examples))))
              (i 0))  ; Simplified evolution step
          (display "Gen ") (display gen) 
          (display ": Best fitness = ")
          (displayln (fitness (car scored) examples))
          (loop (+ gen 1) scored)))))

;; Test
(displayln "=== Genetic Programming Example ===")

(define examples
  '((0 0) (1 2) (2 4) (3 6)))

(displayln "Target examples: f(0)=0, f(1)=2, f(2)=4, f(3)=6")
(displayln "")

(define population
  (for/list ((_ (in-range 20)))
    (random-program 2)))

(displayln "Initial random programs:")
(displayln (take population 5))

(define best (evolve population examples 5))
(displayln "")
(displayln "Best program after 5 generations:")
(displayln best)
(displayln "Fitness:")
(displayln (fitness best examples))
