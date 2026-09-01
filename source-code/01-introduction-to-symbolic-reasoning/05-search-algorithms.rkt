#lang racket

;;; Search Algorithms: BFS and DFS
;;; Demonstrates search techniques from the chapter
;;; The example graph is directed (edges are A->B), not undirected.

(provide graph
         get-neighbors
         bfs
         dfs
         search)

;; Directed graph as adjacency list of pairs
(define graph '(("A" . "B") ("A" . "E") ("B" . "C") ("C" . "D") ("E" . "F") ("F" . "D")))

(define (get-neighbors node)
  (map cdr (filter (lambda (e) (equal? (car e) node)) graph)))

;; Generic graph search parameterized by frontier strategy
;; combiner: (new-paths rest -> new-frontier)
;; trace?: when #t prints processing steps
(define (search start goal combiner #:trace? [trace? #f])
  (cond
    [(equal? start goal) (list start)]
    [else
     (define visited (make-hash))
     (define (mark-visited! n) (hash-set! visited n #t))
     (define (visited? n) (hash-has-key? visited n))
     (mark-visited! start)
     (let loop ([frontier (list (list start))])
       (cond
         [(null? frontier) #f]
         [else
          (define path (car frontier))
          (define node (car path))
          (define rest (cdr frontier))
          (when trace?
            (displayln (format "Processing path: ~a" (reverse path))))
          (if (equal? node goal)
              (reverse path)
              (let* ([nbs (filter-not visited? (get-neighbors node))]
                     [new-paths (map (lambda (n) (cons n path)) nbs)])
                (for-each mark-visited! nbs)
                (when (and trace? (not (null? nbs)))
                  (displayln (format "  Neighbors: ~a" nbs)))
                (loop (combiner new-paths rest))))]))]))

(define (bfs start goal #:trace? [trace? #f])
  (search start goal (lambda (new rest) (append rest new)) #:trace? trace?))

(define (dfs start goal #:trace? [trace? #f])
  (search start goal (lambda (new rest) (append new rest)) #:trace? trace?))

(module+ main
  (displayln "=== Search Algorithms Example ===")
  (displayln "")
  (displayln "Graph is directed; neighbors of A:")
  (displayln (get-neighbors "A"))
  (displayln "")
  (displayln "BFS from A to D (trace):")
  (let ([path (bfs "A" "D" #:trace? #t)])
    (display "Result: ") (displayln path))
  (displayln "")
  (displayln "DFS from A to D (trace):")
  (let ([path (dfs "A" "D" #:trace? #t)])
    (display "Result: ") (displayln path))
  (displayln "")
  (displayln "Start == goal:")
  (displayln (bfs "A" "A"))
  (displayln "No path (A to Z):")
  (displayln (bfs "A" "Z")))

(module+ test
  (require rackunit)
  (check-equal? (get-neighbors "A") '("B" "E"))
  (check-equal? (bfs "A" "D") '("A" "B" "C" "D"))
  (check-equal? (dfs "A" "D") '("A" "B" "C" "D"))
  (check-equal? (bfs "A" "A") '("A"))
  (check-false (bfs "A" "Z"))
  (check-false (dfs "Z" "A")))
