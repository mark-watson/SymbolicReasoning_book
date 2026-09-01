#lang racket

;;; Enumerative Program Search: Bottom-Up
;;; Demonstrates systematic exploration of the program space
;;; This chapter's language is constants only (0-5) to isolate enumeration.
;;; Later chapters add variable x.

(require racket/match)

(provide eval-expr
         matches-examples?
         generate-programs
         bottom-up-search)

;; Language definition: simple arithmetic expressions
;; Grammar: expr ::= number | (+ expr expr) | (* expr expr) | (- expr expr)

(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]
    [_ (raise-argument-error 'eval-expr "arith expr" expr)]))

;; Check if constant expression matches all examples when evaluated as a
;; closed term. For the constant-only language, input is ignored.
;; This is intentional for Chapter 2; Chapter 3 adds variable x.
(define (matches-examples? expr examples)
  (define val (eval-expr expr '()))
  (for/and ([ex examples])
    (equal? val (cadr ex))))

;; Generate programs up to given size (memoized to avoid double recursion)
(define generate-programs
  (let ([cache (make-hash)])
    (lambda (max-size)
      (hash-ref! cache max-size
                 (lambda ()
                   (if (= max-size 1)
                       (list 0 1 2 3 4 5)
                       (let ([base (list 0 1 2 3 4 5)]
                             [subs (generate-programs (max 1 (- max-size 1)))])
                         (remove-duplicates
                          (append base
                                  (for*/list ([a subs] [b subs] [op '(+ * -)])
                                    (list op a b)))))))))))

;; Bottom-up search: enumerate programs and test
(define (bottom-up-search examples max-size)
  (findf (lambda (p) (matches-examples? p examples))
         (generate-programs max-size)))

(module+ main
  (displayln "=== Enumerative Search Example ===")

  (define examples
    '((0 0) (1 2) (2 4) (3 6)))

  (displayln "Target examples: f(0)=0, f(1)=2, f(2)=4, f(3)=6")
  (displayln "Note: This chapter's language is constants only, so f(x)=2x")
  (displayln "cannot be expressed. We search for constant expressions that")
  (displayln "fit subsets of the spec, to isolate enumeration.")
  (displayln "")

  (displayln "Programs of size 1:")
  (define progs-1 (generate-programs 1))
  (display "  ") (displayln progs-1)

  (displayln "")
  (displayln "Programs of size 2:")
  (define progs-2 (generate-programs 2))
  (display "  Sample: ") (displayln (take progs-2 15))

  (displayln "")
  (displayln "Programs of size 3:")
  (define progs-3 (generate-programs 3))
  (display "  Count (deduped): ") (displayln (length progs-3))

  (displayln "")
  (displayln "Search for constant that matches f(0)=0 only:")
  (displayln (bottom-up-search '((0 0)) 2))

  (displayln "")
  (displayln "Note: No single constant fits all four points, so full search fails:")
  (displayln (bottom-up-search examples 2))
  (displayln "Chapter 3 adds variable x, where (+ x x) solves the full spec."))

(module+ test
  (require rackunit)
  (check-equal? (eval-expr '(+ 1 2) '()) 3)
  (check-equal? (eval-expr '(* 2 3) '()) 6)
  (check-equal? (eval-expr '(- 5 1) '()) 4)
  (check-true (matches-examples? 2 '((0 2) (1 2))))
  (check-false (matches-examples? 2 '((0 0) (1 2))))
  (check-not-false (member 0 (generate-programs 1)))
  (check-equal? (bottom-up-search '((0 0)) 1) 0)
  (check-false (bottom-up-search '((0 0) (1 2)) 2)))
