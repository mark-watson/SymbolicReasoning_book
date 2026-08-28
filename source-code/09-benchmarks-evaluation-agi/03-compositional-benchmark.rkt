#lang racket

;;; Compositional Generalization Benchmark (SCAN-style)
;;;
;;; The SCAN benchmark measures compositional generalization in sequence
;;; models by training on short commands and testing on longer ones.
;;; Here we make a 1-D analogue: programs over the primitives
;;;   walk, look, jump, run
;;; combined by `and` and `twice`.  Training uses only short sequences;
;;; the test set requires longer compositions.
;;;
;;; We compare two synthesizers:
;;;   * a length-bounded enumerative synthesizer that can never build
;;;     test-length programs (it fails to generalize), and
;;;   * a compositional synthesizer that models programs recursively
;;;     and therefore extends naturally (it generalizes).

;; ---------- commands and DSL ----------
;; Each command maps a token to a list of primitive steps.
(define command-table
  '((walk . ("walk"))
    (look . ("look"))
    (jump . ("jump"))
    (run  . ("run"))))

(define (expand-command tokens)
  ;; tokens may include non-command atoms like 'and' or 'twice';
  ;; those are simply skipped so a length-bounded synthesizer never
  ;; crashes when it encounters them.
  (apply append
         (map (lambda (t)
                (let ((p (assoc t command-table)))
                  (if p (cdr p) '())))
              tokens)))

;; ---------- tasks ----------
;; Training: sequences of length 2 with no repeats of an action
(define train-examples
  '(( (walk)             . ("walk"))
    ( (look)             . ("look"))
    ( (jump)             . ("jump"))
    ( (walk and look)    . ("walk" "look"))
    ( (look and walk)    . ("look" "walk"))
    ( (jump and look)    . ("jump" "look"))
    ( (walk twice)       . ("walk" "walk"))
    ( (look twice)       . ("look" "look"))))

;; Test: longer compositions — e.g. "(walk and look) twice"
(define test-examples
  '(( (walk and look twice)  . ("walk" "look" "walk" "look"))
    ( (jump and run  twice)  . ("jump" "run" "jump" "run"))))

;; ---------- length-bounded synthesizer ----------
;; Enumerates all command sequences of length <= bounded-length and picks
;; the one most similar to the input.  This cannot reach test length.
(define (length-bounded-synth tokens bounded)
  (if (<= (length tokens) bounded)
      (expand-command tokens)
      ;; can't produce the full output -- return what it can
      (expand-command (take tokens bounded))))

;; ---------- compositional synthesizer ----------
;; Parses the input recursively: the grammar supports
;;   action                  = primitive
;;   action and action       = sequencing
;;   expr twice              = repetition of any expr
(define (parse-tokens tokens)
  ;; returns (cons program rest) or #f
  (cond
    [(null? tokens) #f]
    [(member (car tokens) '(walk look jump run))
     (cons (car tokens) (cdr tokens))]
    [else #f]))

(define (parse-expr tokens)
  ;; Grammar (SCAN-style):
  ;;   expr      :=  seq [twice]
  ;;   seq       :=  primary (and primary)*
  ;;   primary   :=  walk | look | jump | run
  ;; 'twice' applies to the largest subexpression to its left, matching
  ;; the canonical SCAN interpretation ("walk and look twice" means
  ;; "(walk and look) twice").
  (define (parse-primary toks)
    (cond
      [(null? toks) #f]
      [(member (car toks) '(walk look jump run))
       (cons (car toks) (cdr toks))]
      [else #f]))
  (define (parse-seq toks)
    (let loop ((acc (parse-primary toks)))
      (if (not acc)
          #f
          (let ((rest (cdr acc)))
            (if (and (pair? rest) (eq? (car rest) 'and))
                (let ((rhs (parse-primary (cdr rest))))
                  (if rhs
                      (loop (cons (list 'and (car acc) (car rhs))
                                  (cdr rhs)))
                      acc))
                acc)))))
  (let ((s (parse-seq tokens)))
    (if (not s)
        #f
        (let ((rest (cdr s)))
          (if (and (pair? rest) (eq? (car rest) 'twice))
              (cons (list 'twice (car s)) (cdr rest))
              s)))))

;; Evaluate a parsed program to a list of primitive steps
(define (eval-program p)
  (match p
    [(? symbol? a) (cdr (assoc a command-table))]
    [`(and ,x ,y) (append (eval-program x) (eval-program y))]
    [`(twice ,x)  (append (eval-program x) (eval-program x))]
    [_ '()]))

;; ---------- run ----------
(displayln "=== SCAN-Style Compositional Generalization ===")
(displayln (format "Train examples: ~a tasks" (length train-examples)))
(displayln (format "Test examples : ~a tasks" (length test-examples)))
(newline)

(define (summarize fn label)
  (displayln (format "--- ~a ---" label))
  (for ((ex test-examples))
    (let ((input (car ex)) (expected (cdr ex)))
      (define got (fn input))
      (displayln (format "  ~a -> ~a (expected ~a) ~a"
                         input got expected
                         (if (equal? got expected) "OK" "FAIL"))))))

(summarize (lambda (tokens) (length-bounded-synth tokens 2))
           "Length-bounded synthesizer (max depth 2)")

(summarize (lambda (tokens)
             (let ((p (parse-expr tokens)))
               (if p (eval-program (car p)) 'PARSE-FAIL)))
           "Compositional synthesizer (recursive parse)")
