#lang racket

;;; Search Algorithms: BFS and DFS
;;; Demonstrates search techniques from the chapter

;; Graph representation  
(define graph '(("A" . "B") ("A" . "E") ("B" . "C") ("C" . "D") ("E" . "F") ("F" . "D")))

(define (get-neighbors node)
  (map cdr (filter (lambda (e) (equal? (car e) node)) graph)))

;; Breadth-First Search with proper visited tracking
(define (bfs start goal)
  (define visited (make-hash))
  (define (mark-visited! node) (hash-set! visited node #t))
  (define (visited? node) (hash-has-key? visited node))
  
  (mark-visited! start)
  (let loop ((q (list (list start))))
    (if (null? q)
        #f
        (let* ((path (car q))
               (node (car path))  ; Get first element (current node)
               (rest (cdr q)))
          (display "Processing path: ") (displayln path)
          (if (equal? node goal)
              (reverse path)  ; Return path in correct order
              (let* ((nbs (filter (lambda (n) (not (visited? n))) (get-neighbors node)))
                     ;; Create new paths by extending current path
                     (new-paths (map (lambda (n) (cons n path)) nbs)))
                (display "  Neighbors: ") (displayln nbs)
                (for-each mark-visited! nbs)
                ;; Add new paths to END of queue (BFS)
                (loop (append rest new-paths))))))))

;; Depth-First Search with proper visited tracking
(define (dfs start goal)
  (define visited (make-hash))
  (define (mark-visited! node) (hash-set! visited node #t))
  (define (visited? node) (hash-has-key? visited node))
  
  (mark-visited! start)
  (let loop ((stack (list (list start))))
    (if (null? stack)
        #f
        (let* ((path (car stack))
               (node (car path))  ; Get first element (current node)
               (rest (cdr stack)))
          (display "Processing path: ") (displayln path)
          (if (equal? node goal)
              (reverse path)
              (let* ((nbs (filter (lambda (n) (not (visited? n))) (get-neighbors node)))
                     (new-paths (map (lambda (n) (cons n path)) nbs)))
                (display "  Neighbors: ") (displayln nbs)
                (for-each mark-visited! nbs)
                ;; Add new paths to START of stack (DFS)
                (loop (append new-paths rest))))))))

;; Example usage
(displayln "=== Search Algorithms Example ===")

(displayln "")
(displayln "Graph neighbors of A:")
(displayln (get-neighbors "A"))

(displayln "")
(displayln "BFS from A to D:")
(let ((path (bfs "A" "D")))
  (display "Result: ")
  (displayln path))

(displayln "")
(displayln "DFS from A to D:")
(let ((path (dfs "A" "D")))
  (display "Result: ")
  (displayln path))
