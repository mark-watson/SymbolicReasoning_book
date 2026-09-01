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
  (define s (if (eq? subj #f) #f subj))
  (define p (if (eq? pred #f) #f pred))
  (define o (if (eq? obj #f) #f obj))
  (let ([res (find-triples #:subj s #:pred p #:obj o)])
    (if (null? res) #f res)))

;; Find all properties of an object
(define (describe obj)
  (for/list ([t (find-triples #:subj obj)])
    (list (triple-pred t) (triple-obj t))))

;; Find all objects matching (subj pred ?)
(define (find-all subj pred)
  (for/list ([t (find-triples #:subj subj #:pred pred)])
    (triple-obj t)))

;; Proper transitive closure with visited set, handles diamonds and cycles
(define (isa-closure-set start)
  (let loop ([frontier (list start)] [seen (set)])
    (if (null? frontier)
        seen
        (let* ([node (car frontier)]
               [rest (cdr frontier)]
               [parents (find-all node 'isa)]
               [new-pars (filter-not (lambda (p) (set-member? seen p)) parents)])
          (loop (append rest new-pars) (set-add seen node))))))

(define (isa-closure obj acc)
  ;; Legacy signature: (isa-closure obj acc) returns ancestors appended to acc
  ;; New impl delegates to set version
  (define ancestors (set->list (set-remove (isa-closure-set obj) obj)))
  (append ancestors acc))

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
  (check-equal? (set-count (isa-closure-set 'x)) 2))
