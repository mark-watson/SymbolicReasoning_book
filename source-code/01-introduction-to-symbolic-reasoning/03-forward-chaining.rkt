#lang racket

;;; Forward Chaining Inference Engine
;;; Derives new facts from existing rules and facts

(provide (all-defined-out))

;; Knowledge base is a list of facts and rules
;; Facts: (symbol values...)
;; Rules: ((conclusion-var pattern) premise1 premise2 ...)

(define %facts '())

(define (add-fact! fact)
  (set! %facts (cons fact %facts)))

(define (clear-kb!)
  (set! %facts '()))

;; Check if a symbol is a variable (starts with ?)
(define (var? x)
  (and (symbol? x) (char=? (string-ref (symbol->string x) 0) #\?)))

;; Pattern matching with binding
(define (match-pattern pattern fact env)
  (cond
    ((var? pattern)
     (let ((val (assq pattern env)))
       (if val
           (if (equal? (cdr val) fact) env #f)
           (cons (cons pattern fact) env))))
    ((and (pair? pattern) (pair? fact))
     (let ((e1 (match-pattern (car pattern) (car fact) env)))
       (if e1 (match-pattern (cdr pattern) (cdr fact) e1) #f)))
    (else (if (equal? pattern fact) env #f))))

;; Find all matches for a pattern in facts
(define (find-matches pattern facts env)
  (let ((matches '()))
    (for ((f facts))
      (let ((m (match-pattern pattern f env)))
        (when m (set! matches (cons m matches)))))
    matches))

;; Simple forward chaining helper
(define (derive-once rule facts)
  (let ((conclusion (car rule))
        (premises (cdr rule))
        (new-facts '()))
    (let ((envs (if (null? premises)
                    (list '())
                    (foldl (lambda (prem envs)
                             (for/fold ((acc '()))
                               ((env envs))
                               (let ((ms (find-matches prem facts env)))
                                 (append ms acc))))
                           (list '()) premises))))
      (for ((env envs))
        (let ((nf (resolve-pattern conclusion env)))
          (when (and nf (not (member nf facts)))
            (set! new-facts (cons nf new-facts))))))
    new-facts))

;; Main forward chaining loop
(define (forward-chain rules facts max-iterations)
  (let loop ((all-facts facts) (iter 0))
    (if (>= iter max-iterations)
        all-facts
        (let ((all-new '()))
          (for ((rule rules))
            (set! all-new (append (derive-once rule all-facts) all-new)))
          (if (null? all-new)
              all-facts
              (begin
                (display "Iteration ")
                (display iter)
                (display ": Derived ")
                (display (length all-new))
                (display " new facts: ")
                (displayln all-new)
                (loop (append all-new all-facts) (+ iter 1))))))))

;; Resolve pattern variables with environment
(define (resolve-pattern pattern env)
  (cond
    ((var? pattern)
     (let ((val (assq pattern env)))
       (if val (cdr val) pattern)))
    ((pair? pattern)
     (cons (resolve-pattern (car pattern) env)
           (resolve-pattern (cdr pattern) env)))
    (else pattern)))

;; Example: Family relationships
(clear-kb!)

;; Facts
(add-fact! '(parent tom bob))
(add-fact! '(parent bob ann))
(add-fact! '(parent ann sue))
(add-fact! '(parent tom mary))

;; Rules
(define rules
  '(((grandparent ?x ?z) (parent ?x ?y) (parent ?y ?z))))

(displayln "=== Forward Chaining Example ===")
(displayln "Initial facts:")
(for ((f %facts))
  (display "  ")
  (displayln f))
(displayln "")

(let ((result (forward-chain rules %facts 10)))
  (displayln "")
  (displayln "Grandparent facts:")
  (for ((f result))
    (when (eq? (car f) 'grandparent)
      (display "  ")
      (displayln f))))

;; Example: Transitive closure
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
(for ((f %facts))
  (display "  ")
  (displayln f))
(displayln "")

(let ((result (forward-chain transitive-rules %facts 10)))
  (displayln "")
  (displayln "All connected pairs:")
  (for ((f result))
    (when (eq? (car f) 'connected)
      (display "  ")
      (displayln f))))
