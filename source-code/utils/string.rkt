#lang racket

;;; String utilities shared across synthesis chapters
;;; Provides a single canonical string-reverse

(provide string-reverse)

(define (string-reverse s)
  (unless (string? s)
    (raise-argument-error 'string-reverse "string?" s))
  (list->string (reverse (string->list s))))
