#lang racket

;;; Convenience re-export for all shared utilities
;;; Readers can require this single file or the individual modules
;;; under source-code/utils/{string,math,logic,eval}.rkt

(provide (all-from-out "utils/string.rkt")
         (all-from-out "utils/math.rkt")
         (all-from-out "utils/logic.rkt")
         (all-from-out "utils/eval.rkt"))

(require "utils/string.rkt"
         "utils/math.rkt"
         "utils/logic.rkt"
         "utils/eval.rkt")
