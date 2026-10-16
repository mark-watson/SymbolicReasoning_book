#lang racket

;;; Causal and Temporal Reasoning: do-operations on a simple epidemiology DAG
;;; These are interventions (Pearl's rung 2). A true counterfactual (rung 3)
;;; would first infer each unit's background noise from what was observed,
;;; then intervene; this linear toy model has no per-unit noise to infer.

(require (only-in "../utils/math.rkt" clamp01))

(provide baseline links clamp01 link-strength propagate)

(define baseline (hash 'vaccinate 0.4 'infection 0.6 'hospital 0.5))

(define links
  (list (list 'vaccinate 'infection -0.7)
        (list 'infection 'hospital   0.8)))

;; Strength of the edge from -> to; a missing edge is an error, not a
;; silent default, so the model is defined by `links` alone.
(define (link-strength from to)
  (or (for/first ([l links] #:when (and (eq? (first l) from) (eq? (second l) to)))
        (third l))
      (error 'link-strength "no causal link ~a -> ~a" from to)))

(define (propagate interventions)
  (define vaccinate (hash-ref interventions 'vaccinate (hash-ref baseline 'vaccinate)))
  (define infection
    (if (hash-has-key? interventions 'infection)
        (hash-ref interventions 'infection)
        (clamp01 (+ (hash-ref baseline 'infection)
                    (* (link-strength 'vaccinate 'infection) vaccinate)))))
  (define hospital
    (if (hash-has-key? interventions 'hospital)
        (hash-ref interventions 'hospital)
        (clamp01 (+ (hash-ref baseline 'hospital)
                    (* (link-strength 'infection 'hospital) infection)))))
  (hash 'vaccinate vaccinate 'infection infection 'hospital hospital))

(module+ main
  (define obs (propagate (hash)))
  (define do-vax (propagate (hash 'vaccinate (* 2 (hash-ref baseline 'vaccinate)))))
  (define do-inf (propagate (hash 'infection 0.0)))

  (displayln "=== Causal Reasoning with Interventions ===")
  (displayln "Model: vaccinate --(-0.7)--> infection --(+0.8)--> hospital")
  (displayln "Links are read from `links`; strengths are not hard-coded in propagate.")
  (newline)
  (displayln (format "Observational:   vaccinate=~a infection=~a hospital=~a"
                     (hash-ref obs 'vaccinate)
                     (exact->inexact (hash-ref obs 'infection))
                     (exact->inexact (hash-ref obs 'hospital))))
  (displayln (format "do(vaccinate=0.8): vaccinate=~a infection=~a hospital=~a"
                     (hash-ref do-vax 'vaccinate)
                     (exact->inexact (hash-ref do-vax 'infection))
                     (exact->inexact (hash-ref do-vax 'hospital))))
  (displayln (format "do(infection=0):   infection=~a hospital=~a"
                     (hash-ref do-inf 'infection)
                     (exact->inexact (hash-ref do-inf 'hospital))))

  (newline)
  (displayln "An intervention do(X=v) cuts X off from its parents, sets it to v,")
  (displayln "and re-propagates downstream in topological order.")
  (displayln "Doubling vaccinate cuts infection and downstream hospitalizations."))

(module+ test
  (require rackunit)
  (check-= (hash-ref (propagate (hash)) 'infection) 0.32 0.001)
  (check-true (< (hash-ref (propagate (hash 'vaccinate 0.8)) 'infection)
                 (hash-ref (propagate (hash)) 'infection)))
  (check-equal? (hash-ref (propagate (hash 'infection 0.0)) 'infection) 0.0)
  (check-equal? (link-strength 'vaccinate 'infection) -0.7)
  (check-exn exn:fail? (lambda () (link-strength 'hospital 'vaccinate))))
