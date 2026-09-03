#lang racket

;;; Convenience aggregator: re-export all shared helpers in one require.
;;; Chapter files may instead require individual utils when only one
;;; concern is needed, e.g. (require "../utils/math.rkt").

(provide (all-from-out "utils/string.rkt")
         (all-from-out "utils/math.rkt")
         (all-from-out "utils/logic.rkt")
         (all-from-out "utils/eval.rkt"))

(require "utils/string.rkt"
         "utils/math.rkt"
         "utils/logic.rkt"
         "utils/eval.rkt")
