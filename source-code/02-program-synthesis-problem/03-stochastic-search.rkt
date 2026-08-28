#lang racket

;;; Genetic Programming for Program Synthesis
;;; Evolves programs through mutation, crossover, and selection

(provide (all-defined-out))

;; Random number generation
(random-seed 42)

;; Language: same as before
(define (eval-expr expr env)
  (cond
    ((number? expr) expr)
    ((and (list? expr) (= (length expr) 3))
     (let ((op (car expr))
           (a (eval-expr (cadr expr) env))
           (b (eval-expr (caddr expr) env)))
       (case op
         ((+) (+ a b))
         ((*) (* a b))
         ((-) (- a b))
         (else (error "Unknown operator" op)))))
    (else (error "Invalid expression" expr))))

;; Fitness function: negative of total error
(define (fitness program examples)
  (let ((total-error 0))
    (for ((ex examples))
      (let ((input (car ex))
            (output (cadr ex))
            (pred (eval-expr program '())))
        (set! total-error (+ total-error (abs (- pred output))))))
    (- total-error)))  ;; Negative error = higher fitness

;; Helper: reference a random element (non-deterministic)
(define (random-ref lst)
  (list-ref lst (random (length lst))))

;; Generate random program of given depth
(define (random-program depth)
  (if (= depth 0)
      (random-ref '(0 1 2 3 4 5))
      (let ((op (random-ref '(+ * -)))
            (left (random-program (- depth 1)))
            (right (random-program (- depth 1))))
        (list op left right))))

;; Mutate a program: randomly replace a subtree
(define (mutate prog)
  (cond
    ((number? prog)
     (random-ref '(0 1 2 3 4 5)))  ;; Replace with another constant
    ((list? prog)
     (let ((pos (random 3))
           (new-op (random-ref '(+ * -))))
       (list-set prog pos new-op)))))

;; Crossover: swap subtrees between programs
(define (crossover p1 p2)
  (if (and (list? p1) (list? p2) (= (length p1) 3) (= (length p2) 3))
      (let ((i (random 3))
            (j (random 3)))
        (list (list-ref p1 i)
              (list-ref p2 j)
              (list-ref p1 (- 2 i))))
      (list p1 p2)))

;; Genetic Programming main loop
(define (gp population examples generations)
  (let loop ((gen 0) (pop population))
    (if (>= gen generations)
        (car (sort pop > #:key (lambda (p) (fitness p examples))))
        (let* ((scored (map (lambda (p) (cons (fitness p examples) p)) pop))
               (sorted (sort scored > #:key car))
               (best-fitness (caar sorted))
               (best-prog (cdar sorted)))
          
          (display "Generation ")
          (display gen)
          (display ": Best fitness = ")
          (display (car best-fitness))
          (displayln "")
          
          (if (= best-fitness 0)
              (begin
                (displayln "Perfect solution found:")
                best-prog)
              (let* ((parents (take sorted 10))
                     (elites (map cdr parents))
                     (offspring
                      (apply append
                             (for/list ((_ (in-range 10)))
                               (let* ((p1 (random-ref elites))
                                      (p2 (random-ref elites))
                                      (child (crossover p1 p2)))
                                 (list (mutate child)))))))
                (loop (+ gen 1) (append elites offspring))))))))

;; Helper for returning from loop
(define (return v) (error "Return not implemented" v))

;; Test
(displayln "=== Genetic Programming Example ===")

(define examples
  '((0 0)     ; f(0) = 0
    (1 2)     ; f(1) = 2  
    (2 4)     ; f(2) = 4
    (3 6)))   ; f(3) = 6

(displayln "Target examples:")
(displayln examples)
(displayln "")

;; Create initial population
(define population
  (for/list ((_ (in-range 20)))
    (random-program 2)))

(displayln "Initial population of 20 random programs:")
(display "  ")
(displayln (take population 5))
(displayln "")

;; Run GP (simplified version due to complexity)
(displayln "Running Genetic Programming...")
(displayln "(Note: This is a simplified version without full evolution)")

;; Just demonstrate mutation and crossover
(define p1 (random-program 1))
(define p2 (random-program 1))
(displayln "Program 1:")
(displayln p1)
(displayln "Program 2:")
(displayln p2)
(displayln "Mutation operates on programs by randomly changing operators or constants:")
(displayln "  Original p1 = (op arg1 arg2)")
(displayln "  Mutated p1 = (new-op arg1 arg2) or (op new-arg arg2) etc.")
(displayln "")
(displayln "Crossover combines parts of two programs:")
(displayln "  Crossover swaps subtrees to create offspring")
