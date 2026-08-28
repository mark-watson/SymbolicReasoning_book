#lang racket

;;; Causal and Temporal Reasoning in Synthesis
;;;
;;; Scientific understanding is causal, not merely correlational.
;;; This example represents a small causal model as a program with
;;; explicit interventions: a simple epidemiology model in which
;;;   vaccinate -> infection  (vaccination reduces infections)
;;;   infection -> hospital   (infection drives hospitalization)
;;; Each link has a strength in [0,1] and the model supports
;;; do-operations (Pearl-style interventions) so we can ask
;;; counterfactual questions like "what if vaccination doubles?"
;;;
;;; The model is deliberately simple: each variable's value is a
;;; deterministic function of its parents' values, times its link
;;; strength.  Cycles are absent so evaluation is well-defined.

;; ---------- causal graph structure ----------
;; nodes: vaccinate, infection, hospital
;; edges: vaccination reduces infection strength (negative influence),
;;        infection increases hospitalization.

;; baseline propensities
(define baseline
  (hash 'vaccinate 0.4
        'infection 0.6
        'hospital  0.5))

;; link strengths (signed): parent -> effect on child
(define links
  (list (list 'vaccinate 'infection -0.7)   ; vaccinate lowers infection
        (list 'infection 'hospital   0.8)))

;; ---------- deterministic propagation ----------
;; child value = clamp(parent-based contribution), computed in
;; topological order, optionally with interventions overriding parents.
(define (clamp01 x) (max 0.0 (min 1.0 x)))

(define (propagate interventions)
  ;; interventions: hash of node -> forced value
  (define vaccinate
    (hash-ref interventions 'vaccinate
              (hash-ref baseline 'vaccinate)))
  ;; infection = baseline infection shifted by the vaccinate link
  (define infection
    (if (hash-has-key? interventions 'infection)
        (hash-ref interventions 'infection)
        (clamp01 (+ (hash-ref baseline 'infection)
                    (* -0.7 vaccinate)))))
  ;; hospital = baseline hospital shifted by the infection link
  (define hospital
    (if (hash-has-key? interventions 'hospital)
        (hash-ref interventions 'hospital)
        (clamp01 (+ (hash-ref baseline 'hospital)
                    (* 0.8 infection)))))
  (hash 'vaccinate vaccinate
        'infection infection
        'hospital  hospital))

;; ---------- observational run ----------
(define obs (propagate (hash)))

;; ---------- counterfactual: what if vaccination doubles? ----------
(define cf (propagate (hash 'vaccinate (* 2 (hash-ref baseline 'vaccinate)))))

;; ---------- counterfactual: what if we could eliminate infection? ----------
(define cf2 (propagate (hash 'infection 0.0)))

;; ---------- report ----------
(displayln "=== Causal & Counterfactual Reasoning ===")
(displayln "Model: vaccinate --(-0.7)--> infection --(+0.8)--> hospital")
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
(displayln "Interpretation:")
(displayln "  Counterfactual queries are answered by overriding parent")
(displayln "  values and re-running propagation through the causal links.")
(displayln "  Doubling vaccination cuts infection, which in turn lowers")
(displayln "  hospitalization even though the policy didn't target it")
(displayln "  directly; eliminating infection has the largest downstream")
(displayln "  effect.  This is the kind of reasoning a symbolic causal")
(displayln "  model supports but a correlational one cannot.")
