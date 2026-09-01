#lang racket

;;; Stochastic Search / Genetic Programming for Program Synthesis
;;; Evolves programs through subtree mutation and crossover

(require racket/match)

(provide eval-expr
         fitness
         random-program
         random-ref
         mutate
         crossover
         gp)

(random-seed 42)

;; Language: (+ * -) over constants
(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]
    [_ (raise-argument-error 'eval-expr "arith expr" expr)]))

;; Fitness: negative total error. For constant language, env is ignored.
(define (fitness program examples)
  (define total-error
    (for/sum ([ex examples])
      (match-define (list input output) ex)
      (define pred (eval-expr program '()))
      (abs (- pred output))))
  (- total-error))

(define (random-ref lst)
  (list-ref lst (random (length lst))))

(define (random-program depth)
  (if (= depth 0)
      (random-ref '(0 1 2 3 4 5))
      (let ([op (random-ref '(+ * -))]
            [left (random-program (- depth 1))]
            [right (random-program (- depth 1))])
        (list op left right))))

;; Collect all subtrees of prog (including prog itself)
(define (subtrees prog)
  (cons prog
        (if (list? prog)
            (append (subtrees (cadr prog)) (subtrees (caddr prog)))
            '())))

;; Replace a random subtree of prog with new-sub
(define (replace-random-subtree prog new-sub)
  (if (or (number? prog) (= (random 3) 0))
      new-sub
      (let ([pos (random 2)])
        (if (= pos 0)
            (list (car prog) (replace-random-subtree (cadr prog) new-sub) (caddr prog))
            (list (car prog) (cadr prog) (replace-random-subtree (caddr prog) new-sub))))))

;; Mutate by replacing a random subtree with a fresh random program
(define (mutate prog)
  (replace-random-subtree prog (random-program 1)))

;; Crossover: swap a random subtree of p1 with a random subtree of p2
(define (crossover p1 p2)
  (cond
    [(and (list? p1) (list? p2))
     (define sub2 (random-ref (subtrees p2)))
     (replace-random-subtree p1 sub2)]
    [else (random-ref (list p1 p2))]))

;; Genetic Programming loop
(define (gp population examples generations)
  (let loop ([gen 0] [pop population])
    (if (>= gen generations)
        (argmax (lambda (p) (fitness p examples)) pop)
        (let* ([scored (sort pop > #:key (lambda (p) (fitness p examples)))]
               [best (car scored)]
               [best-fitness (fitness best examples)])
          (displayln (format "Generation ~a: Best fitness = ~a (prog ~a)" gen best-fitness best))
          (if (= best-fitness 0)
              best
              (let* ([parents (take scored (min 10 (length scored)))]
                     [elites (map (lambda (x) x) parents)]
                     [offspring
                      (for/list ([_ (in-range 10)])
                        (define p1 (random-ref elites))
                        (define p2 (random-ref elites))
                        (mutate (crossover p1 p2)))])
                (loop (+ gen 1) (append elites offspring))))))))

(module+ main
  (displayln "=== Genetic Programming Example ===")

  (define examples '((0 0) (1 2) (2 4) (3 6)))

  (displayln "Target examples:")
  (displayln examples)
  (displayln "")
  (displayln "Note: constant-only language cannot represent 2*x, so fitness")
  (displayln "never reaches 0. This isolates mutation/crossover mechanics.")
  (displayln "")

  (define population
    (for/list ([_ (in-range 20)]) (random-program 2)))

  (displayln "Initial population of 20 random programs (sample 5):")
  (displayln (take population 5))
  (displayln "")

  (displayln "Running GP for 3 generations:")
  (define best (gp population examples 3))
  (displayln (format "Best after 3 gens: ~a fitness ~a" best (fitness best examples)))
  (displayln "")

  (define p1 (random-program 1))
  (define p2 (random-program 1))
  (displayln (format "Program 1: ~a" p1))
  (displayln (format "Program 2: ~a" p2))
  (displayln (format "Mutate p1: ~a" (mutate p1)))
  (displayln (format "Crossover p1 x p2: ~a" (crossover p1 p2)))
  (displayln "Mutation now replaces a random subtree, not a random position.")
  (displayln "Crossover swaps a random subtree between parents."))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(+ 1 2) '()) 3)
  (check-true (or (number? (mutate '(+ 1 2))) (list? (mutate '(+ 1 2)))))
  (check-true (number? (fitness '(+ 1 1) '((0 2)))))
  ;; subtree crossover preserves number-or-list shape
  (check-true (or (number? (crossover '(+ 1 2) '(* 3 4))) (list? (crossover '(+ 1 2) '(* 3 4)))))
  (check-equal? (fitness 2 '((0 2) (1 2))) 0))
