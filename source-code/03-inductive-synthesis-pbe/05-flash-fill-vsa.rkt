#lang racket

;;; Flash Fill-style synthesis with a version space algebra.
;;; A program is (concat atom ...), where an atom is (const "s") or
;;; (substr p1 p2) and positions p are:
;;;   (cpos k)      k >= 0 counts from the start, k < 0 from the end (-1 = end)
;;;   (before c n)  the index of the n-th occurrence of character c
;;;   (after c n)   the index just past the n-th occurrence of c
;;; with n < 0 counting occurrences from the end (-1 = last).
;;;
;;; The version space for one example is a DAG over output indices 0..m.
;;; Edge i->j holds every atom that produces out[i..j), and a substr atom
;;; holds two sets of positions instead of one position each, so one edge
;;; stands for |P1| x |P2| programs. Learning from several examples is DAG
;;; intersection, and no program is ever listed one by one.

(provide eval-pos
         eval-program
         positions-for
         example-dag
         dag-intersect
         learn
         count-programs
         best-program
         run-program)

(require racket/match)

(define separators '(#\space #\, #\- #\@ #\. #\/))

(define (occurrences s c)
  (for/list ([ch s] [i (in-naturals)] #:when (char=? ch c)) i))

(define (nth-occurrence s c n)
  (define occ (occurrences s c))
  (define k (length occ))
  (cond [(and (> n 0) (<= n k)) (list-ref occ (- n 1))]
        [(and (< n 0) (<= (- n) k)) (list-ref occ (+ k n))]
        [else #f]))

(define (eval-pos p s)
  (define len (string-length s))
  (match p
    [`(cpos ,k) (let ([i (if (>= k 0) k (+ len 1 k))]) (and (<= 0 i len) i))]
    [`(before ,c ,n) (nth-occurrence s c n)]
    [`(after ,c ,n) (let ([i (nth-occurrence s c n)]) (and i (+ i 1)))]))

;; Every position expression that evaluates to index a on s.
(define (positions-for s a)
  (define len (string-length s))
  (append
   (list `(cpos ,a) `(cpos ,(- a len 1)))
   (for*/list ([c separators]
               [occ (in-value (occurrences s c))]
               [i occ]
               [k (in-value (length occ))]
               [n (in-value (+ 1 (index-of occ i)))]
               [p (list `(before ,c ,n) `(before ,c ,(- n k 1))
                        `(after ,c ,n) `(after ,c ,(- n k 1)))]
               #:when (eqv? (eval-pos p s) a))
     p)))

(define (eval-atom atom s)
  (match atom
    [`(const ,str) str]
    [`(substr ,p1 ,p2)
     (define i (eval-pos p1 s))
     (define j (eval-pos p2 s))
     (and i j (<= i j) (substring s i j))]))

(define (eval-program prog s)
  (match-define (cons 'concat atoms) prog)
  (define parts (map (lambda (a) (eval-atom a s)) atoms))
  (and (andmap values parts) (apply string-append parts)))

;; A version space DAG: edges maps a node to a list of (target . atoms),
;; where atoms are (const "s") or (substr P1-set P2-set).
(struct dag (start end edges) #:transparent)

(define (substring-starts s piece)
  (for/list ([a (in-range 0 (+ 1 (- (string-length s) (string-length piece))))]
             #:when (string=? (substring s a (+ a (string-length piece))) piece))
    a))

(define (example-dag in out)
  (define m (string-length out))
  (define pos-cache (for/vector ([a (in-range (+ 1 (string-length in)))]) (positions-for in a)))
  (dag 0 m
       (for/hash ([i (in-range m)])
         (values i
                 (for/list ([j (in-range (+ i 1) (+ m 1))])
                   (define piece (substring out i j))
                   (cons j
                         (cons `(const ,piece)
                               (for/list ([a (substring-starts in piece)])
                                 `(substr ,(vector-ref pos-cache a)
                                          ,(vector-ref pos-cache (+ a (- j i))))))))))))

(define (set-meet xs ys) (filter (lambda (x) (member x ys)) xs))

(define (atom-meet a1 a2)
  (match* (a1 a2)
    [(`(const ,s1) `(const ,s2)) (and (string=? s1 s2) a1)]
    [(`(substr ,p1 ,p2) `(substr ,q1 ,q2))
     (define r1 (set-meet p1 q1))
     (define r2 (set-meet p2 q2))
     (and (pair? r1) (pair? r2) `(substr ,r1 ,r2))]
    [(_ _) #f]))

;; Product construction: node (u . v) has an edge to (u2 . v2) carrying the
;; pairwise meets of the atoms on u->u2 and v->v2. Only reachable nodes are built.
(define (dag-intersect d1 d2)
  (define start (cons (dag-start d1) (dag-start d2)))
  (define edges (make-hash))
  (let visit ([node start])
    (unless (hash-has-key? edges node)
      (define out
        (for*/list ([e1 (hash-ref (dag-edges d1) (car node) '())]
                    [e2 (hash-ref (dag-edges d2) (cdr node) '())]
                    [atoms (in-value (remove-duplicates
                                      (for*/list ([a1 (cdr e1)] [a2 (cdr e2)]
                                                    #:when (atom-meet a1 a2))
                                          (atom-meet a1 a2))))]
                    #:when (pair? atoms))
          (cons (cons (car e1) (car e2)) atoms)))
      (hash-set! edges node out)
      (for ([e out]) (visit (car e)))))
  (dag start (cons (dag-end d1) (dag-end d2)) (for/hash ([(k v) edges]) (values k v))))

(define (learn examples)
  (for/fold ([d (example-dag (first (first examples)) (second (first examples)))])
            ([ex (rest examples)])
    (dag-intersect d (example-dag (first ex) (second ex)))))

(define (atom-count a)
  (match a
    [`(const ,_) 1]
    [`(substr ,p1 ,p2) (* (length p1) (length p2))]))

;; Exact number of programs in the version space, by dynamic programming.
(define (count-programs d)
  (define memo (make-hash))
  (let count ([node (dag-start d)])
    (cond [(equal? node (dag-end d)) 1]
          [else
           (hash-ref! memo node
                      (lambda ()
                        (for/sum ([e (hash-ref (dag-edges d) node '())])
                          (* (for/sum ([a (cdr e)]) (atom-count a))
                             (count (car e))))))])))

;; Ranking. 'tokens prefers start/end and separator positions, the choice
;; Flash Fill's ranker makes; 'cpos prefers fixed character offsets.
(define (pos-rank p prefer)
  (match p
    [`(cpos 0) 0]
    [`(cpos -1) 0]
    [`(cpos ,_) (if (eq? prefer 'cpos) 1 2)]
    [_ (if (eq? prefer 'cpos) 2 1)]))

(define (pick-pos ps prefer)
  (argmin (lambda (p) (pos-rank p prefer)) ps))

;; Substrings cost 3; a constant costs 2 plus 2 per character, so the ranker
;; explains output with input text whenever it can.
(define (atom-cost a)
  (match a
    [`(const ,s) (+ 2 (* 2 (string-length s)))]
    [`(substr ,_ ,_) 3]))

(define (concrete a prefer)
  (match a
    [`(const ,_) a]
    [`(substr ,p1 ,p2) `(substr ,(pick-pos p1 prefer) ,(pick-pos p2 prefer))]))

(define (best-program d [prefer 'tokens])
  (define memo (make-hash))
  (define (best node)
    (if (equal? node (dag-end d))
        (cons 0 '())
        (hash-ref! memo node
                   (lambda ()
                     (for*/fold ([acc #f])
                                ([e (hash-ref (dag-edges d) node '())]
                                 [rest (in-value (best (car e)))]
                                 #:when rest
                                 [a (cdr e)])
                       (define c (+ (atom-cost a) (car rest)))
                       (if (or (not acc) (< c (car acc)))
                           (cons c (cons (concrete a prefer) (cdr rest)))
                           acc))))))
  (define r (best (dag-start d)))
  (and r (cons 'concat (cdr r))))

(define (run-program prog s) (and prog (eval-program prog s)))

(define (show-task title examples tests)
  (printf "=== ~a ===\n" title)
  (for ([k (in-range 1 (+ 1 (length examples)))])
    (define d (learn (take examples k)))
    (define prog (best-program d))
    (printf "After ~a example~a: ~a programs in the version space\n"
            k (if (= k 1) "" "s") (count-programs d))
    (printf "  best: ~s\n" prog)
    (for ([t tests])
      (printf "  ~s -> ~s\n" t (run-program prog t))))
  (newline))

(module+ main
  (show-task "Swap first and last name"
             '(("john smith" "smith, john") ("ada lovelace" "lovelace, ada"))
             '("alan turing"))

  (displayln "=== Why the second example matters ===")
  (define one (learn '(("john smith" "smith, john"))))
  (define two (learn '(("john smith" "smith, john") ("ada lovelace" "lovelace, ada"))))
  (define p1 (best-program one 'cpos))
  (define p2 (best-program two 'cpos))
  (printf "One example, offset-loving ranker: ~s\n" p1)
  (printf "  on \"grace hopper\" -> ~s\n" (run-program p1 "grace hopper"))
  (printf "Two examples, offset-loving ranker: ~s\n" p2)
  (printf "  on \"grace hopper\" -> ~s\n\n" (run-program p2 "grace hopper"))

  (show-task "Format a phone number"
             '(("5551234567" "555-123-4567"))
             '("8005550199"))

  (show-task "User name from an email address"
             '(("alan.turing@bletchley.org" "turing")
               ("grace.hopper@navy.mil" "hopper"))
             '("ada.lovelace@analytical.uk"))

  (show-task "Initials (beyond this DSL)"
             '(("grace hopper" "g.h.") ("ada lovelace" "a.l."))
             '("alan turing")))

(module+ test
  (require rackunit)
  (check-equal? (eval-pos '(cpos -1) "abc") 3)
  (check-equal? (eval-pos '(after #\space 1) "john smith") 5)
  (check-equal? (eval-pos '(before #\@ -1) "a@b@c") 3)
  (check-false (eval-pos '(after #\- 1) "abc"))
  (check-not-false (member '(after #\space 1) (positions-for "john smith" 5)))

  (define names '(("john smith" "smith, john") ("ada lovelace" "lovelace, ada")))
  (define two (learn names))
  (define p (best-program two))
  (check-equal? (run-program p "alan turing") "turing, alan")
  (for ([ex names]) (check-equal? (run-program p (first ex)) (second ex)))
  (check-true (< (count-programs two) (count-programs (learn (take names 1)))))

  ;; one example leaves offset programs that do not generalize
  (check-not-equal? (run-program (best-program (learn (take names 1)) 'cpos) "grace hopper")
                    "hopper, grace")
  (check-equal? (run-program (best-program two 'cpos) "alan turing") "turing, alan")

  (check-equal? (run-program (best-program (learn '(("5551234567" "555-123-4567"))))
                             "8005550199")
                "800-555-0199")
  (check-equal? (run-program (best-program (learn '(("alan.turing@bletchley.org" "turing")
                                                    ("grace.hopper@navy.mil" "hopper"))))
                             "ada.lovelace@analytical.uk")
                "lovelace")
  (check-false (best-program (learn '(("grace hopper" "g.h.") ("ada lovelace" "a.l."))))))
