#lang racket

;;; Simple Semantic Network Representation
;;; Nodes represent concepts, edges represent relationships

(provide (all-defined-out))

;; Semantic network is a list of triples: (subject predicate object)
(define %network '())

(define (add-triple! subj pred obj)
  (set! %network (cons (list subj pred obj) %network)))

(define (clear-network!)
  (set! %network '()))

;; Query the network
(define (query subj pred obj)
  (let ((results '()))
    (for ((triple %network))
      (let ((s (car triple))
            (p (cadr triple))
            (o (caddr triple)))
        (when (and (eq? subj s) (eq? pred p) (eq? obj o))
          (set! results (cons triple results)))))
    (if (null? results) #f results)))

;; Find all properties of an object
(define (describe obj)
  (let ((results '()))
    (for ((triple %network))
      (let ((s (car triple))
            (p (cadr triple))
            (o (caddr triple)))
        (when (eq? s obj)
          (set! results (cons (list p o) results)))))
    results))

;; Find all objects matching a pattern
(define (find-all subj pred)
  (let ((results '()))
    (for ((triple %network))
      (let ((s (car triple))
            (p (cadr triple))
            (o (caddr triple)))
        (when (and (eq? subj s) (eq? pred p))
          (set! results (cons o results)))))
    results))  ; Return the accumulated results

;; Transitive closure of isa relation
(define (isa-closure obj acc)
  (let ((parents (find-all obj 'isa)))
    (if (null? parents)
        acc
        (foldl isa-closure (cons (car parents) acc) parents))))

;; Example: Building a knowledge network
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
(let ((closure (isa-closure 'dog '())))
  (for ((c closure))
    (display "  ")
    (displayln c)))

(displayln "")
(displayln "Describe dog:")
(let ((desc (describe 'dog)))
  (for ((d desc))
    (display "  ")
    (display (car d))
    (display ": ")
    (displayln (cadr d))))

(displayln "")
(displayln "Does dog have fur (inherited from mammal)?")
(let ((mammal-props (describe 'mammal)))
  (if (memq 'fur (map cadr mammal-props))
      (displayln "  Yes (inherits from mammal)")
      (displayln "  No")))

(displayln "")
(displayln "What does sparrow eat?")
(displayln (find-all 'sparrow 'eats))

(displayln "")
(displayln "What sound does a cat make?")
(displayln (find-all 'cat 'sound))
