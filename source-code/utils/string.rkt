#lang racket

;;; String utilities shared across synthesis chapters
;;; Provides a single canonical string-reverse and helpers

(provide string-reverse
         string-trim*)

(define (string-reverse s)
  (unless (string? s)
    (raise-argument-error 'string-reverse "string?" s))
  (list->string (reverse (string->list s))))

(define (string-trim* s) (string-trim s))
