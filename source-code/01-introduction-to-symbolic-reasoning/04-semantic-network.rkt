#lang racket

;;; Simple Semantic Network Representation
;;; Nodes represent concepts, edges represent relationships stored as triples

(provide triple
         triple-subj triple-pred triple-obj
         current-network
         add-triple!
         clear-network!
         query
         find-triples
         describe
         find-all
         isa-closure
         isa-closure-set
         isa-ancestors
         inherits?)

(require racket/set)

(struct triple (subj pred obj) #:transparent)

;; Parameterized network so require has no side effect
(define current-network (make-parameter '()))

(define (add-triple! subj pred obj)
  (current-network (cons (triple subj pred obj) (current-network))))

(define (clear-network!)
  (current-network '()))

;; Unified find with optional wildcards (#f means wildcard)
(define (find-triples #:subj [subj #f] #:pred [pred #f] #:obj [obj #f])
  (for/list ([t (current-network)]
             #:when (and (or (not subj) (eq? (triple-subj t) subj))
                         (or (not pred) (eq? (triple-pred t) pred))
                         (or (not obj)  (eq? (triple-obj t) obj))))
    t))

;; Query with exact or wildcard (#f = wildcard). Returns #f if no match.
(define (query subj pred obj)
  (let ([res (find-triples #:subj subj #:pred pred #:obj obj)])
    (if (null? res) #f res)))

;; Find all properties of an object
(define (describe obj)
  (for/list ([t (find-triples #:subj obj)])
    (list (triple-pred t) (triple-obj t))))

;; Find all objects matching (subj pred ?)
(define (find-all subj pred)
  (for/list ([t (find-triples #:subj subj #:pred pred)])
    (triple-obj t)))

;; Breadth-first walk up the isa links with a visited set, so diamonds and
;; cycles terminate. Returns start followed by its ancestors, nearest first.
(define (isa-ancestors start)
  (let loop ([frontier (list start)] [seen (set start)] [order '()])
    (if (null? frontier)
        (reverse order)
        (let* ([node (car frontier)]
               [new-pars (remove-duplicates
                          (filter-not (lambda (p) (set-member? seen p))
                                      (find-all node 'isa)))])
          (loop (append (cdr frontier) new-pars)
                (foldl (lambda (p s) (set-add s p)) seen new-pars)
                (cons node order))))))

(define (isa-closure-set start)
  (list->set (isa-ancestors start)))

;; (isa-closure obj acc): ancestors of obj, nearest first, appended to acc
(define (isa-closure obj acc)
  (append (cdr (isa-ancestors obj)) acc))

;; Check if obj inherits property (pred -> val) via isa chain
(define (inherits? obj pred val)
  (for/or ([ancestor (set->list (isa-closure-set obj))])
    (member val (find-all ancestor pred))))

(module+ main
  (displayln "=== Semantic Network Example ===")
  (clear-network!)

  ;; Animal taxonomy
  (add-triple! 'mammal 'isa 'animal)
  (add-triple! 'dog 'isa 'mammal)
  (add-triple! 'cat 'isa 'mammal)
  (add-triple! 'bird 'isa 'animal)
  (add-triple! 'sparrow 'isa 'bird)

  ;; Properties
  (add-triple! 'mammal 'has 'fur)
  (add-triple! 'bird 'has 'feathers)
  (add-triple! 'dog 'sound 'bark)
  (add-triple! 'cat 'sound 'meow)
  (add-triple! 'sparrow 'sound 'chirp)

  ;; Relationships
  (add-triple! 'dog 'eats 'meat)
  (add-triple! 'cat 'eats 'meat)
  (add-triple! 'sparrow 'eats 'seeds)

  (displayln "")
  (displayln "What is dog's parent?")
  (displayln (find-all 'dog 'isa))

  (displayln "")
  (displayln "ISA chain from dog to top:")
  (for ([c (isa-closure 'dog '())])
    (display "  ") (displayln c))

  (displayln "")
  (displayln "ISA ancestors (set, includes self):")
  (displayln (sort (set->list (isa-closure-set 'dog)) symbol<?))

  (displayln "")
  (displayln "Describe dog:")
  (for ([d (describe 'dog)])
    (display "  ") (display (car d)) (display ": ") (displayln (cadr d)))

  (displayln "")
  (displayln "Does dog have fur (inherited from mammal)?")
  (if (inherits? 'dog 'has 'fur)
      (displayln "  Yes (inherits from mammal)")
      (displayln "  No"))

  (displayln "")
  (displayln "What does sparrow eat?")
  (displayln (find-all 'sparrow 'eats))

  (displayln "")
  (displayln "What sound does a cat make?")
  (displayln (find-all 'cat 'sound))

  (displayln "")
  (displayln "Wildcard query: all isa triples")
  (displayln (query #f 'isa #f)))

(module+ test
  (require rackunit)
  (clear-network!)
  (add-triple! 'mammal 'isa 'animal)
  (add-triple! 'dog 'isa 'mammal)
  (add-triple! 'mammal 'has 'fur)
  (check-equal? (find-all 'dog 'isa) '(mammal))
  (check-not-false (member 'animal (isa-closure 'dog '())))
  (check-not-false (member 'mammal (isa-closure 'dog '())))
  (check-not-false (inherits? 'dog 'has 'fur))
  (check-false (inherits? 'sparrow 'has 'fur))
  (check-not-false (query 'dog 'isa 'mammal))
  (check-not-false (query #f 'isa #f))
  ;; Diamond / cycle safety
  (clear-network!)
  (add-triple! 'a 'isa 'b)
  (add-triple! 'a 'isa 'c)
  (add-triple! 'b 'isa 'd)
  (add-triple! 'c 'isa 'd)
  (check-equal? (set-count (isa-closure-set 'a)) 4) ; a,b,c,d
  (clear-network!)
  (add-triple! 'x 'isa 'y)
  (add-triple! 'y 'isa 'x)
  (check-equal? (set-count (isa-closure-set 'x)) 2)
  ;; isa-closure is ordered nearest ancestor first
  (clear-network!)
  (add-triple! 'mammal 'isa 'animal)
  (add-triple! 'dog 'isa 'mammal)
  (check-equal? (isa-closure 'dog '()) '(mammal animal)))
