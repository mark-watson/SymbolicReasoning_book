# Chapter 6: Neurosymbolic Architectures & Algorithms

The previous chapter explored the neurosymbolic paradigm as a design pattern: neural nets for perception, symbolic engines for reasoning, and a smooth interface that connects them. This chapter tours four concrete architectures that realize that pattern, each with a working example written in Racket. These architectures—Logic Tensor Networks (LTN), Logical Neural Networks (LNN), NeurASP, and Differentiable Inductive Logic Programming (∂ILP)—share the same goal but differ in the trade-offs they make between expressivity, training stability, and interpretability.

All code examples are in `source-code/06-neurosymbolic-architectures/` and are written in plain Racket so that every step is visible. Shared `dot`, `sigmoid`, and t-norm helpers are imported from `source-code/utils/math.rkt` and `utils/logic.rkt`; each file now has an explicit `provide` and `(module+ main ...)`/`(module+ test ...)` so `require` is silent. None requires an external solver.

The figure below draws all four in one visual language. Blue boxes hold learned parameters, green boxes hold symbolic structure, gray boxes hold data or a score, and dashed arrows show where gradients flow. Keep it in view as you read: the four systems differ mainly in where the green boxes sit and whether the gradient passes through them.

![Four neurosymbolic architectures in one visual language](images/ch6-architectures.png)

## Logic Tensor Networks (LTN)

Logic Tensor Networks (LTN) treat logical formulas as computations over tensors. Constants in a first-order language are mapped to embedding vectors, predicates are neural nets that map tuples of embeddings to truth degrees in [0,1], and logical connectives are smooth relaxations built from t-norms. The key insight is that, with these choices, logical inference becomes differentiable: one can adjust the parameters of the predicates—and even the constants themselves—via gradient descent to maximize the degree of satisfaction of a knowledge base.

The example `01-logic-tensor-network.rkt` implements a minimal LTN. Constants are structs holding a name and an embedding:

```racket
(struct const (name embedding) #:transparent)
(define alice (const 'alice '(0.9 0.1)))
(define bob   (const 'bob   '(0.7 0.6)))
(define carol (const 'carol '(0.4 0.8)))
```

Predicates are structs with a mutable weight vector. Evaluating a predicate takes the dot product of its weights with the concatenated embeddings—`dot` and `sigmoid` are imported from `utils/math.rkt`—and checks that the concatenated length matches the weight length:

```racket
(require "../utils/math.rkt" "../utils/logic.rkt")
(struct pred (name [weights #:mutable]) #:transparent)
(define (eval-pred p args)
  (define embs (apply append (map eval-const args)))
  (unless (= (length embs) (length (pred-weights p)))
    (raise-argument-error 'eval-pred "weights length vs embedding length" 0 p args))
  (sigmoid (dot (pred-weights p) embs)))
;; t-and, t-impl are imported from utils/logic.rkt
```

We encode the rule ∀x,y (friend(x,y) ∧ likes(x,sports) → likes(y,sports)) by first writing a per-grounding satisfaction function:

```racket
(define (rule-satisfaction x y)
  (let* ((fxy (eval-pred friend (list x y)))
         (lsx (eval-pred likes-sports (list x)))
         (lsy (eval-pred likes-sports (list y)))
         (premise (t-and fxy lsx)))
    (t-impl premise lsy)))
```

and then generalizing it to the whole domain with a product over all pairs:

```racket
(define (kb-satisfaction)
  (t-and-list
   (for*/list ((x (list alice bob carol))
               (y (list alice bob carol)))
     (rule-satisfaction x y))))
```

Because every step is differentiable, we can perform gradient ascent on the parameters to maximize the KB satisfaction. The full gradient code from `01-logic-tensor-network.rkt` — a central finite difference over each weight of a predicate, carefully restoring the original weights before returning:

```racket
(define (numeric-grad p)
  (define orig (pred-weights p))
  (for/list ([i (in-range (length orig))])
    (define w+ (list-set orig i (+ (list-ref orig i) h)))
    (define w- (list-set orig i (- (list-ref orig i) h)))
    (set-pred-weights! p w+)
    (define sat+ (kb-satisfaction))
    (set-pred-weights! p w-)
    (define sat- (kb-satisfaction))
    (set-pred-weights! p orig)
    (/ (- sat+ sat-) (* 2 h))))
```

The output shows the KB satisfaction rise after a hundred ascent steps (from about `0.148` to `0.249`), with the predicate weights moving in the direction preferred by the rule. LTNs have been used for knowledge‑base completion, semantic image interpretation, and any setting where a structured set of logical constraints must be reconciled with noisy learned models.

## Logical Neural Networks (LNN)

Logical Neural Networks (LNN) take a complementary stance: the structure of a logical formula is mapped directly onto a neural network. Each neuron computes a subformula’s truth value, and the connections mirror the formula’s parse tree. Input neurons hold degrees of belief for atomic facts; internal neurons implement connectives such as AND and IMPL; and the network output is the degree of truth of the full formula.

The example `02-logical-neural-network.rkt` defines neurons as a small struct type:

```racket
(struct neuron (kind [inputs #:mutable] [value #:mutable]) #:transparent)
```

where `kind` is either `'input`, `'and`, or `'impl`. Evaluation is now split into a pure walk that does not mutate and a caching wrapper, so `neuron-grad` (which does finite differences on `q`) does not leave stale `impl`/`and` values:

```racket
(require "../utils/logic.rkt")
(define (eval-neuron-pure n)
  (match (neuron-kind n)
    ['input (neuron-value n)]
    ['and (t-and-list (map eval-neuron-pure (neuron-inputs n)))]
    ['impl (t-impl (eval-neuron-pure (first (neuron-inputs n)))
                   (eval-neuron-pure (second (neuron-inputs n))))]))
(define (eval-neuron n) (define v (eval-neuron-pure n)) (set-neuron-value! n v) v)
```

The example uses the product t-norm (`t-and-list`) and Reichenbach implication (`t-impl`) from `utils/logic.rkt`, the same connectives as the LTN example. IBM's LNN uses weighted Łukasiewicz logic and tracks upper and lower bounds on each truth value; the product form keeps this example short.

Building the network for a simple theory `P AND (P -> Q)` looks like:

```racket
(define p (neuron 'input '() 0.9))
(define q (neuron 'input '() 0.2))
(define impl-node (neuron 'impl (list p q) #f))
(define net (neuron 'and (list p impl-node) #f))
```

To make learning concrete, the implementation also computes a finite‑difference gradient of the network output with respect to the input neuron `q` and performs a short gradient‑ascent loop. The full `neuron-grad` from `02-logical-neural-network.rkt` perturbs the target's value symmetrically and restores it afterwards — which is exactly why evaluation above is split into a pure walk; the gradient would otherwise read stale cached values:

```racket
(define (neuron-grad net target-neuron eps)
  (define orig (neuron-value target-neuron))
  (set-neuron-value! target-neuron (min 1.0 (+ orig eps)))
  (define hi (eval-neuron-pure net))
  (set-neuron-value! target-neuron (max 0.0 (- orig eps)))
  (define lo (eval-neuron-pure net))
  (set-neuron-value! target-neuron orig)
  (/ (- hi lo) (* 2 eps)))
```

After a few dozen steps the value of `q`—initially low—rises toward `1.0`, and the overall network output rises from `0.252` to `0.9`. This is precisely the classical modus‑ponens behavior, but produced by gradient descent: the implication neuron penalizes states where `P` is high and `Q` is low, so the overall AND score improves only when `Q` goes up. LNNs thus allow both forward inference (deriving consequences) and backward inference (abducing likely premises) in the same network, and their learned parameters can be read off as the relative importance or confidence attached to each logical connection.

## NeurASP: Integrating Answer Set Programming with Neural Networks

NeurASP bridges the declarative power of Answer Set Programming (ASP) with the pattern‑recognition power of neural nets. In a NeurASP system, a neural network acts as an oracle that produces probabilities over atomic facts (e.g., object classes in an image). These probabilities are then embedded in an ASP program, whose stable models correspond to solutions that satisfy symbolic constraints. Crucially, the training objective—maximize the probability of the correct answer set—gradients flow *through* the ASP solving step back into the neural network, so the network learns to produce perceptions that are consistent with the ASP rules.

The example `03-neurasp.rkt` imports `dot`/`sigmoid` from `utils/math.rkt` and `t-impl` from `utils/logic.rkt`. The neural component is:

```racket
(require "../utils/math.rkt" "../utils/logic.rkt")
(define (nn-scores img ws) (map (lambda (w) (sigmoid (dot img w))) ws))
```

The ASP component is represented as a set of soft rules—each rule is a clause that takes a hash of atom‑to‑probability mappings and returns a satisfaction degree. For example:

```racket
(define (rule-sat probs)
  (let* ((c-red  (hash-ref probs 'red))
         (c-blue (hash-ref probs 'blue))
         (s-circ (hash-ref probs 'circle))
         (s-sq   (hash-ref probs 'square))
         (c-flag (hash-ref probs 'flag)))
    (list
     (t-impl (* c-red s-circ) c-flag)
     (t-impl (* c-blue s-sq)   c-flag)
     (t-impl (* c-red s-sq)   (- 1.0 c-flag)) ; red & square -> NOT flag
     (t-impl (* c-blue s-circ) (- 1.0 c-flag)))))
```

The training loop is where the example earned a rewrite. The draft maximized rule satisfaction alone — the product of those four implications — but that objective rewards any world where the rules hold, including worlds with low `flag` (rules three and four are satisfied when `flag` is near 0). The reader watched `P(flag)` fall even as "satisfaction" rose: correct arithmetic, wrong lesson. Real NeurASP maximizes the probability of the *observed answer* given perception, so the objective must include a data term. Our image is a red circle observed with label `flag = 1`, and the objective becomes:

```racket
(define (objective ws)
  (define probs (hash-from-weights ws))
  (* (total-satisfaction probs)          ; prior: rules hold
     (hash-ref probs 'flag)))            ; data: P(flag = observed label)
```

A finite‑difference gradient over the NN weights followed by gradient ascent now pushes the way the rules and the label agree it should:

```
NeurASP toy: objective = rule satisfaction x P(label):
  Rule satisfaction initial: 0.551  final: 0.544
  P(flag) initial: 0.454
  P(flag) final  : 0.492
  Objective initial: 0.250  final: 0.268
```

Rule satisfaction dips slightly but the data term dominates: ascent strengthens the circle-detecting neuron for this red‑circle image, and `P(flag)` rises. Flip the label to `flag = 0` and the same objective pushes `P(flag)` down — the direction of learning comes from the data, not from the rules alone. That is exactly the NeurASP division of labor: the ASP rules shape the space of worlds the network may believe in, and the observation selects among them.

NeurASP shows how to reuse mature symbolic solvers (clingo) for structured prediction while still learning the perceptual front‑end. The key takeaway is that the symbolic layer does not need to be rewritten as a differentiable layer; rather, its *output* (a stable‑model probability) is differentiable, and that gradient path — combined with a data term anchoring outputs to labels — is enough to couple learning and reasoning.

## Differentiable Inductive Logic Programming (∂ILP)

Inductive Logic Programming (ILP) learns logic programs from examples, but classical ILP relies on symbolic search over a discrete space of clauses and is not differentiable. Differentiable ILP (∂ILP) relaxes that discreteness: instead of committing to a single rule, it learns a *soft* selection over a set of candidate rules, with the selection expressed as a softmax over learnable weights. Inference then computes a weighted combination of candidate rule applications, a process that is end‑to‑end differentiable.

The example `04-dilp.rkt` factors the repeated `for/or` chain into a `chain` helper, uses `softmax` explicitly, and derives the constants that intermediate variables range over from the database itself (`db-constants`), so adding facts extends the chain domain without editing the evaluator. The three candidates are:

```racket
(define (eval-rule r kb x z)
  (define (chain rel1 rel2)
    (for/or ([y (db-constants kb)])
      (and (holds? kb rel1 x y) (holds? kb rel2 y z))))
  (case r
    [(R1) (if (chain 'parent 'parent) 1.0 0.0)]
    [(R2) (if (chain 'parent 'sibling) 1.0 0.0)]
    [(R3) (if (chain 'sibling 'parent) 1.0 0.0)]
    [else 0.0]))
```

The database argument is named `kb`, not `db`, because `db` is also the name of the struct constructor, and a parameter named `db` would hide it inside the function.

Given rule weights, inference computes a softmax over the weights and produces a weighted sum of the candidate scores:

```racket
(define (softmax ws)
  (define exps (map exp ws))
  (define sum (apply + exps))
  (map (lambda (e) (/ e sum)) exps))

(define (infer-grandparent weights kb x z)
  (define scores (for/list ([r '(R1 R2 R3)]) (eval-rule r kb x z)))
  (define probs (softmax weights))
  (apply + (map * probs scores)))
```

Training minimizes a mean‑squared‑error loss between the inferred score and the target truth value for positive and negative examples. The gradient is again computed numerically, and gradient descent drives the rule weights until the softmax puts nearly all its mass on the correct rule `R1`. The final softmax, shown in the output, sharply favors `R1` (~0.896) over the alternatives, and inference on held‑out examples behaves accordingly.

∂ILP illustrates how to combine the interpretability of ILP with the flexibility of gradient descent. Because the candidate rules are explicit and readable, the resulting model remains auditable: you can inspect the learned softmax and see which logical rule the system has come to rely on. At the same time, the relaxation allows the system to learn from noisy examples and to be trained jointly with neural components when the clauses themselves have learned parameters.

## Running the Examples

All four are explicit-`provide` modules with `(module+ main ...)`/`(module+ test ...)`; `require` is silent:

```bash
cd source-code/06-neurosymbolic-architectures
racket 01-logic-tensor-network.rkt
racket 02-logical-neural-network.rkt
racket 03-neurasp.rkt
racket 04-dilp.rkt
raco test .
```

Each output narrates the architectural idea in miniature: the LTN prints its KB‑satisfaction before and after ascent; the LNN prints its network output and how a belief neuron is updated; NeurASP prints the satisfaction of its soft rules and the probability change of a derived atom; and ∂ILP prints its learning loss and the final softmax over rule templates.

## Wrap Up

These four architectures demonstrate different points on the neurosymbolic design space. LTNs and LNNs map logic directly onto tensor computations—LTNs at the level of embeddings and t‑norms, LNNs at the level of neurons that compute connectives—making them naturally end‑to‑end differentiable. NeurASP keeps the symbolic component (ASP) largely intact, using a probabilistic interface to couple it with a neural front‑end. ∂ILP keeps the symbolic form of clauses but softens the selection over them, preserving interpretability while permitting gradient training. All four show that the neurosymbolic paradigm, introduced in the previous chapter, can be instantiated in concrete, trained systems that combine perception, reasoning, and learning in a single architecture.

As we move to advanced topics in the next part of this book, these architectures form a practical toolbox: you can choose the one whose balance of structure, differentiability, and scalability best matches a given problem, and you can often compose them (for example, using an LNN to score candidate formulas that are then filtered by an ASP solver). The examples in this directory are intentionally minimal, but each captures the core mechanic so you can lift it into larger systems or compare it with published implementations.
