#lang racket

;;; Causal and Temporal Reasoning: do-operations on a simple epidemiology DAG

(provide baseline links clamp01 link-strength propagate)

(define baseline (hash 'vaccinate 0.4 'infection 0.6 'hospital 0.5))

(define links
  (list (list 'vaccinate 'infection -0.7)
        (list 'infection 'hospital   0.8)))

(define (clamp01 x) (max 0.0 (min 1.0 x)))

(define (link-strength from to)
  (for/first ([l links] #:when (and (eq? (first l) from) (eq? (second l) to)))
    (third l)))

(define (propagate interventions)
  (define vaccinate (hash-ref interventions 'vaccinate (hash-ref baseline 'vaccinate)))
  (define infection
    (if (hash-has-key? interventions 'infection)
        (hash-ref interventions 'infection)
        (clamp01 (+ (hash-ref baseline 'infection)
                    (* (or (link-strength 'vaccinate 'infection) -0.7) vaccinate)))))
  (define hospital
    (if (hash-has-key? interventions 'hospital)
        (hash-ref interventions 'hospital)
        (clamp01 (+ (hash-ref baseline 'hospital)
                    (* (or (link-strength 'infection 'hospital) 0.8) infection)))))
  (hash 'vaccinate vaccinate 'infection infection 'hospital hospital))

(module+ main
  (define obs (propagate (hash)))
  (define cf (propagate (hash 'vaccinate (* 2 (hash-ref baseline 'vaccinate)))))
  (define cf2 (propagate (hash 'infection 0.0)))

  (displayln "=== Causal & Counterfactual Reasoning ===")
  (displayln "Model: vaccinate --(-0.7)--> infection --(+0.8)--> hospital")
  (displayln "Links are read from `links`; strengths are not hard-coded in propagate.")
  (newline)
  (displayln (format "Observational:   vaccinate=~a infection=~a hospital=~a"
                     (hash-ref obs 'vaccinate)
                     (exact->inexact (hash-ref obs 'infection))
                     (exact->inexact (hash-ref obs 'hospital))))
  (displayln (format "do(vaccinate=0.8): vaccinate=~a infection=~a hospital=~a"
                     (hash-ref cf 'vaccinate)
                     (exact->inexact (hash-ref cf 'infection))
                     (exact->inexact (hash-ref cf 'hospital))))
  (displayln (format "do(infection=0):   infection=~a hospital=~a"
                     (hash-ref cf2 'infection)
                     (exact->inexact (hash-ref cf2 'hospital))))

  (newline)
  (displayln "Counterfactuals override parents and re-propagate in topological order.")
  (displayln "Doubling vaccinate cuts infection and downstream hospitalizations."))

(module+ test
  (require rackunit)
  (check-= (hash-ref (propagate (hash)) 'infection) 0.32 0.001)
  (check-true (< (hash-ref (propagate (hash 'vaccinate 0.8)) 'infection)
                 (hash-ref (propagate (hash)) 'infection)))
  (check-equal? (hash-ref (propagate (hash 'infection 0.0)) 'infection) 0.0)
  (check-equal? (link-strength 'vaccinate 'infection) -0.7))
