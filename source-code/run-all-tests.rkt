#lang racket

;;; Run every chapter's rackunit checks without cd-ing into each directory.
;;; Usage:  racket source-code/run-all-tests.rkt
;;; Exits non-zero if any chapter's tests fail.

(require racket/system
         racket/runtime-path)

(define-runtime-path here ".")

;; chapter directories are the NN-* subdirectories of this file's directory
(define (chapter-dirs)
  (sort
   (filter (lambda (p)
             (and (directory-exists? (build-path here p))
                  (regexp-match #rx"^[0-9][0-9]-" (path->string p))))
           (directory-list here))
   (lambda (a b) (string<? (path->string a) (path->string b)))))

(define (run-all)
  (define fails '())
  (for ([d (chapter-dirs)])
    (define dir (build-path here d))
    (printf "=== ~a ===\n" d)
    (flush-output)
    (define ok
      (parameterize ([current-directory dir])
        (system* (find-executable-path "raco") "test" ".")))
    (unless ok (set! fails (cons d fails))))
  (newline)
  (if (null? fails)
      (displayln "All chapter test suites passed.")
      (displayln (format "Failures in: ~a" (reverse fails))))
  (null? fails))

(module+ main
  (exit (if (run-all) 0 1)))
