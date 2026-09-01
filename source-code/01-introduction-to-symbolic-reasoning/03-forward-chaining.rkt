#lang racket

;;; Forward Chaining Inference Engine
;;; Derives new facts from existing rules and facts
;;; Rules are (conclusion premise1 premise2 ...) where conclusion and
;;; premises may contain ?-variables.

(provide var?
         match-pattern
         find-matches
         derive-once
         forward-chain
         resolve-pattern
         current-facts
         add-fact!
         clear-kb!)

;; Parameterized knowledge base so requiring the file has no global side effect
(define current-facts (make-parameter '()))

(define (add-fact! fact)
  (current-facts (cons fact (current-facts))))

(define (clear-kb!)
  (current-facts '()))

;; Check if a symbol is a variable (starts with ?)
(define (var? x)
  (and (symbol? x)
       (> (string-length (symbol->string x)) 0)
       (char=? (string-ref (symbol->string x) 0) #\?)))

;; Pattern matching with binding env (alist ?var -> value)
(define (match-pattern pattern fact env)
  (cond
    [(var? pattern)
     (let ([val (assq pattern env)])
       (if val
           (if (equal? (cdr val) fact) env #f)
           (cons (cons pattern fact) env)))]
    [(and (null? pattern) (null? fact)) env]
    [(and (pair? pattern) (pair? fact))
     (let ([e1 (match-pattern (car pattern) (car fact) env)])
       (and e1 (match-pattern (cdr pattern) (cdr fact) e1)))]
    [else (if (equal? pattern fact) env #f)]))

;; Find all matches for a pattern in facts
(define (find-matches pattern facts env)
  (for/list ([f facts]
             #:when (match-pattern pattern f env))
    (match-pattern pattern f env)))

;; Resolve pattern variables with environment
(define (resolve-pattern pattern env)
  (cond
    [(var? pattern)
     (let ([val (assq pattern env)])
       (if val (cdr val) pattern))]
    [(pair? pattern)
     (cons (resolve-pattern (car pattern) env)
           (resolve-pattern (cdr pattern) env))]
    [else pattern]))

;; One round: apply each rule once, collecting new facts
;; Naive: no indexing, no RETE. Re-derives are filtered by membership.
(define (derive-once rule facts)
  (define conclusion (car rule))
  (define premises (cdr rule))
  (define envs
    (if (null? premises)
        (list '())
        (foldl (lambda (prem envs)
                 (append-map (lambda (env) (find-matches prem facts env)) envs))
               (list '()) premises)))
  (filter values
          (for/list ([env envs] #:when env)
            (define nf (resolve-pattern conclusion env))
            (if (and nf (not (member nf facts))) nf #f))))

;; Main forward chaining loop (pure over the passed facts)
;; max-iterations caps the fixpoint search. Set #:trace? to print.
(define (forward-chain rules facts max-iterations #:trace? [trace? #f])
  (let loop ([all-facts facts] [iter 0])
    (if (>= iter max-iterations)
        all-facts
        (let ([all-new (append-map (lambda (rule) (derive-once rule all-facts)) rules)])
          (if (null? all-new)
              all-facts
              (begin
                (when trace?
                  (displayln (format "Iteration ~a: Derived ~a new facts: ~a" iter (length all-new) all-new)))
                (loop (append all-new all-facts) (+ iter 1))))))))

(module+ main
  (displayln "=== Forward Chaining Example ===")
  (clear-kb!)
  (add-fact! '(parent tom bob))
  (add-fact! '(parent bob ann))
  (add-fact! '(parent ann sue))
  (add-fact! '(parent tom mary))

  (define rules
    '(((grandparent ?x ?z) (parent ?x ?y) (parent ?y ?z))))

  (displayln "Initial facts:")
  (for ([f (current-facts)])
    (display "  ") (displayln f))
  (displayln "")

  (let ([result (forward-chain rules (current-facts) 10 #:trace? #t)])
    (displayln "")
    (displayln "Grandparent facts:")
    (for ([f result] #:when (eq? (car f) 'grandparent))
      (display "  ") (displayln f)))

  (displayln "")
  (displayln "=== Transitive Closure Example ===")
  (clear-kb!)
  (add-fact! '(edge a b))
  (add-fact! '(edge b c))
  (add-fact! '(edge c d))
  (add-fact! '(edge d e))

  (define transitive-rules
    '(((connected ?x ?y) (edge ?x ?y))
      ((connected ?x ?z) (edge ?x ?y) (connected ?y ?z))))

  (displayln "Initial facts:")
  (for ([f (current-facts)])
    (display "  ") (displayln f))
  (displayln "")

  (let ([result (forward-chain transitive-rules (current-facts) 10 #:trace? #t)])
    (displayln "")
    (displayln "All connected pairs:")
    (for ([f result] #:when (eq? (car f) 'connected))
      (display "  ") (displayln f))))

(module+ test
  (require rackunit)
  (check-equal? (match-pattern '(parent ?x ?y) '(parent tom bob) '())
                '((?y . bob) (?x . tom)))
  (check-false (match-pattern '(parent ?x ?x) '(parent a b) '()))
  (check-equal? (resolve-pattern '(grandparent ?x ?z) '((?x . tom) (?z . ann)))
                '(grandparent tom ann))
  (let ([facts '((parent a b) (parent b c))]
        [rules '(((grandparent ?x ?z) (parent ?x ?y) (parent ?y ?z)))])
    (check-not-false (member '(grandparent a c) (forward-chain rules facts 5))))
  (let ([facts '((edge a b) (edge b c))]
        [rules '(((connected ?x ?y) (edge ?x ?y))
                 ((connected ?x ?z) (edge ?x ?y) (connected ?y ?z)))])
    (define res (forward-chain rules facts 5))
    (check-not-false (member '(connected a c) res))))
