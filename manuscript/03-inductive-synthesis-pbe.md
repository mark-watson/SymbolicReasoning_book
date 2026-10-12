# Chapter 3: Inductive Synthesis & Programming by Example (PBE)

*Part II: Core Methods in Program Synthesis.*

Programming by Example (PBE) is the most direct form of synthesis: a user gives input-output pairs and the system infers a program. It is also the most proven in industry. Flash Fill, which shipped in Microsoft Excel 2013, lets a spreadsheet user type one or two cleaned-up values and fills the rest of the column with a synthesized string program. The user never sees the program; they see a column that is right.

This chapter moves from the constant-only language of Chapter 2 to grammars with variables and shows four ways to search them: whole-string primitives, version spaces, evolutionary search, and a version space algebra in the style of Flash Fill. The first three examples are small on purpose and each stops at a clear limit. The fourth removes those limits and is the longest program in this part of the book.

All code for this chapter is in `source-code/03-inductive-synthesis-pbe/`. `string-reverse` comes from `source-code/utils/string.rkt`. Each file keeps demos in `(module+ main ...)` and checks in `(module+ test ...)`.

## String Transformations with Whole-String Primitives

`01-pbe-string-transform.rkt` starts with the smallest useful DSL: four whole-string operations, plus an expression evaluator for `concat`, `take`, and `drop` that later examples build on.

```racket
(require "../utils/string.rkt")

(struct string-op (name func) #:transparent)
(define +operations+
  (list (string-op "reverse" string-reverse)
        (string-op "to-upper" string-upcase)
        (string-op "to-lower" string-downcase)
        (string-op "trim" string-trim)))

(define (eval-string-expr expr input)
  (match expr
    [(? string? s) s]
    ['input input]
    [`(concat ,args ...) (apply string-append (map (lambda (a) (eval-string-expr a input)) args))]
    [`(take ,s ,n) (substring (eval-string-expr s input) 0 n)]
    [`(drop ,s ,n) (substring (eval-string-expr s input) n)]
    [_ (raise-argument-error 'eval-string-expr "string expr" expr)]))

(define (learn-transform examples)
  (for/or ([op +operations+])
    (and (for/and ([ex examples]) (equal? ((string-op-func op) (car ex)) (cadr ex))) op)))
```

`learn-transform` tries each primitive and returns the first one that maps every input to its output. On `("john smith" "smith, john")` it returns `#f`, and the demo says why:

```
No single primitive fits name formatting.
This DSL has no split/concat on space; a richer DSL would
learn (concat (second (split input " ")) ", " (first ...)).
```

That failure is the point of the example. A synthesizer can only find programs its DSL can express, and a DSL of whole-string operations cannot pull a word out of a string. The last section of this chapter adds substrings and positions and learns this exact task.

## Version Spaces

A version space is the set of every program in the DSL that fits the examples seen so far. Each new example can only shrink it. `02-version-space.rkt` holds the set in a `vs` struct and shows two ways to shrink it: filter by one example at a time, or filter by each example on its own and intersect the results.

```racket
(require "../utils/string.rkt")
(struct vs (desc candidates) #:transparent)

(define (vs-update example old-vs)
  (match-define (list input output) example)
  (vs (vs-desc old-vs)
      (filter (lambda (c) (equal? (apply-operation c input) output))
              (vs-candidates old-vs))))

(define (vs-intersect vs1 vs2)
  (vs (vs-desc vs1) (filter (lambda (c) (member c (vs-candidates vs2))) (vs-candidates vs1))))
```

The demo filters `hello -> olleh` down to `(reverse)` and `HELLO -> hello` down to `(to-lower)`:

```
Initial candidates: 4
After 'hello' -> 'olleh': 1 candidates (reverse)
After 'HELLO' -> 'hello': 1 candidates (to-lower)
Intersection of the two filtered spaces: ()
No single primitive is both reverse and to-lower.
Sequential filter (hello->olleh then HELLO->hello): ()
```

Both routes give the same empty answer, and that is the key property: filtering in sequence and intersecting give the same result. Flash Fill depends on it, because it lets the system build one version space per example and combine them afterward.

This version stores the candidates as a plain list. With four candidates that costs nothing. With a billion it is not possible, and the Flash Fill section shows how to store a billion programs in a few hundred edges.

## Stochastic and Evolutionary Search

`03-genetic-programming.rkt` leaves strings for arithmetic over a variable `x`, so that `f(x) = 2x` is learnable, and searches by evolution rather than by enumeration. Mutation swaps a random subtree for a fresh random one. Crossover grafts a subtree of one parent into the other.

```racket
(define (eval-expr expr env)
  (match expr
    [(? number? n) n]
    [(? symbol? s) (hash-ref env s s)]
    [`(+ ,a ,b) (+ (eval-expr a env) (eval-expr b env))]
    [`(* ,a ,b) (* (eval-expr a env) (eval-expr b env))]
    [`(- ,a ,b) (- (eval-expr a env) (eval-expr b env))]))

(define (mutate prog) (replace-random-subtree prog (random-program 1)))
(define (crossover p1 p2)
  (if (and (list? p1) (list? p2))
      (replace-random-subtree p1 (random-ref (subtrees p2)))
      (random-ref (list p1 p2))))

(define (evolve population examples generations)
  (let loop ([gen 0] [pop population])
    (if (>= gen generations) (argmax (lambda (p) (fitness p examples)) pop)
        (let* ([scored (sort pop > #:key (lambda (p) (fitness p examples)))]
               [parents (take scored (max 2 (quotient (length scored) 2)))])
          (loop (+ gen 1) (append parents (for/list ([_ parents]) (mutate (crossover (random-ref parents) (random-ref parents))))))))))
```

`fitness` evaluates a program with `(hash 'x input)` and scores it by negative error, so `0` is perfect. `evolve` keeps the top half of the population as parents and breeds the same number of children. A fixed `(random-seed 3)` at the top of the file makes the run repeat exactly:

```
Gen 0: Best fitness = 0 prog (- (* 3 x) (* 1 x))
Gen 1: Best fitness = 0 prog (- (* 3 x) (* 1 x))
...
Best program after 5 generations: (- (* 3 x) (* 1 x))
Check: (0 2 4 6)
```

The winner, `3x - x`, is already in the random population at generation 0, and elitist selection keeps it unchanged. That is worth a pause. With only 20 random depth-2 programs over `{+, *, -}` and leaves that include `x`, a correct program often turns up at once, and evolution's job is to *keep* it rather than to find it. Evolution earns its cost on larger spaces, where no random sample is likely to contain the answer and partial credit from `fitness` guides the search.

## Flash Fill in a Toy DSL

`04-flash-fill-demo.rkt` frames the task as Flash Fill does, with a column of examples, but keeps the whole-string DSL of the first example. It learns `HELLO -> hello` as `lower`, and it states that phone formatting (`1234567890 -> 123-456-7890`) and name swapping are out of reach:

```
Note: This toy DSL has only whole-string ops, so phone
formatting cannot be learned. Real FlashFill uses substring
extraction with regex and position logic.
```

The demo's closing list names what is missing: substring extraction, positions, and pattern matching. The next section builds all three.

## The Flash Fill Algorithm: A Version Space Algebra

Gulwani's 2011 paper "Automating String Processing in Spreadsheets Using Input-Output Examples" describes the algorithm behind Flash Fill. It has three parts:

1. A DSL in which a program joins a list of pieces, and each piece is either a constant string or a substring of the input that lies between two *positions*.
2. A data structure that holds every program in that DSL consistent with an example, without listing them one by one.
3. An intersection operation on that data structure, plus a ranking function that picks one program from what is left.

`05-flash-fill-vsa.rkt` builds a small version of each part.

### The DSL

A program is `(concat atom ...)`. An atom is `(const "s")` or `(substr p1 p2)`. Positions say where a substring starts and ends:

- `(cpos k)`: a fixed offset. `k >= 0` counts from the start; `k < 0` counts from the end, so `(cpos -1)` is the end of the string.
- `(before c n)`: the index of the `n`-th occurrence of the character `c`.
- `(after c n)`: the index just past the `n`-th occurrence of `c`.

As with `cpos`, a negative `n` counts from the end, so `(after #\space -1)` means "just past the last space". The separators are space, comma, hyphen, `@`, period, and slash.

```racket
(define (eval-pos p s)
  (define len (string-length s))
  (match p
    [`(cpos ,k) (let ([i (if (>= k 0) k (+ len 1 k))]) (and (<= 0 i len) i))]
    [`(before ,c ,n) (nth-occurrence s c n)]
    [`(after ,c ,n) (let ([i (nth-occurrence s c n)]) (and i (+ i 1)))]))
```

The real Flash Fill DSL is richer in two ways. Its positions match regular-expression tokens (for example, "the start of the second run of digits"), and a top-level conditional picks between programs when the inputs come in different formats. The structure, though, is the same, and so is the algorithm.

### One example as a DAG

Take the example `"john smith" -> "smith, john"`. Number the gaps between the output's characters `0` to `11`. Every program in the DSL that prints this output splits it into pieces, so every program is a path from node `0` to node `11`, and each step of the path prints one slice of the output.

That observation gives the data structure. Build a directed acyclic graph (DAG) with a node for each output position and an edge `i -> j` for every slice. On each edge, store every atom that prints that slice: the constant, plus one `substr` atom for each place the slice occurs in the input.

The second trick makes the structure small. A `substr` atom does not store one start position and one end position. It stores the *set* of every position expression that evaluates to the right index:

```racket
(define (positions-for s a)
  (define len (string-length s))
  (append
   (list `(cpos ,a) `(cpos ,(- a len 1)))
   (for*/list ([c separators]
               [occ (in-value (occurrences s c))]
               [i occ]
               [k (in-value (length occ))]
               [n (in-value (+ 1 (index-of occ i)))]
               [p (list `(before ,c ,n) `(before ,c ,(- n k 1))
                        `(after ,c ,n) `(after ,c ,(- n k 1)))]
               #:when (eqv? (eval-pos p s) a))
     p)))
```

For index 5 of `"john smith"`, `positions-for` returns `(cpos 5)`, `(cpos -6)`, `(after #\space 1)`, and `(after #\space -1)`. A `substr` atom with four start positions and two end positions stands for eight programs but costs six list entries. Across a whole DAG these products multiply, which is why the word "algebra" fits: the structure stores sums of products of sets, and the program count falls out by arithmetic.

```racket
(define (example-dag in out)
  (define m (string-length out))
  (define pos-cache (for/vector ([a (in-range (+ 1 (string-length in)))]) (positions-for in a)))
  (dag 0 m
       (for/hash ([i (in-range m)])
         (values i
                 (for/list ([j (in-range (+ i 1) (+ m 1))])
                   (define piece (substring out i j))
                   (cons j
                         (cons `(const ,piece)
                               (for/list ([a (substring-starts in piece)])
                                 `(substr ,(vector-ref pos-cache a)
                                          ,(vector-ref pos-cache (+ a (- j i))))))))))))
```

`count-programs` counts paths by dynamic programming. Each edge contributes one program per constant and `|P1| x |P2|` per `substr` atom:

```racket
(define (count-programs d)
  (define memo (make-hash))
  (let count ([node (dag-start d)])
    (cond [(equal? node (dag-end d)) 1]
          [else
           (hash-ref! memo node
                      (lambda ()
                        (for/sum ([e (hash-ref (dag-edges d) node '())])
                          (* (for/sum ([a (cdr e)]) (atom-count a))
                             (count (car e))))))])))
```

For the name example the answer is 1,211,394,080 programs, held in a DAG of 66 edges.

![The version space for one example, and what survives intersection with a second](images/ch3-version-space-dag.png)

### Intersection

A second example, `"ada lovelace" -> "lovelace, ada"`, has its own DAG. The programs that fit *both* examples are the paths that exist in both DAGs at once. `dag-intersect` builds that set with a product construction: node `(u . v)` pairs a node from each DAG, and an edge `(u . v) -> (u2 . v2)` carries the pairwise meets of the atoms on `u -> u2` and `v -> v2`.

```racket
(define (atom-meet a1 a2)
  (match* (a1 a2)
    [(`(const ,s1) `(const ,s2)) (and (string=? s1 s2) a1)]
    [(`(substr ,p1 ,p2) `(substr ,q1 ,q2))
     (define r1 (set-meet p1 q1))
     (define r2 (set-meet p2 q2))
     (and (pair? r1) (pair? r2) `(substr ,r1 ,r2))]
    [(_ _) #f]))
```

Two constants meet only if they are the same string. Two substrings meet by intersecting their position sets. The meet drops every expression that worked for one example by accident. `(cpos 5)` finds the start of `"smith"` but not the start of `"lovelace"`, so it vanishes; `(after #\space 1)` works for both, so it stays. `dag-intersect` only builds nodes it can reach from the start, so the product stays far smaller than the full cross product of the two DAGs.

The version space falls from 1.2 billion programs to 7,056, and every survivor is a general rule.

### Ranking

Even 7,056 programs is too many to show a user, so Flash Fill ranks them and returns the best one. `best-program` finds the cheapest path through the DAG. A substring costs 3, and a constant costs 2 plus 2 per character, so the ranker explains output with input text whenever it can and keeps constants short. Within a position set, it prefers the start and end of the string, then separator positions, then fixed offsets.

```racket
(define (atom-cost a)
  (match a
    [`(const ,s) (+ 2 (* 2 (string-length s)))]
    [`(substr ,_ ,_) 3]))
```

These weights are a choice, and the demo shows that the choice matters. Here is the run:

```
=== Swap first and last name ===
After 1 example: 1211394080 programs in the version space
  best: (concat (substr (after #\space 1) (cpos -1)) (const ", ") (substr (cpos 0) (before #\space 1)))
  "alan turing" -> "turing, alan"
After 2 examples: 7056 programs in the version space
  best: (concat (substr (after #\space 1) (cpos -1)) (const ", ") (substr (cpos 0) (before #\space 1)))
  "alan turing" -> "turing, alan"
```

The ranker picks the general program from a single example, because it prefers separator positions. Swap in a ranker that prefers fixed offsets and the picture changes:

```
=== Why the second example matters ===
One example, offset-loving ranker: (concat (substr (cpos 5) (cpos -1)) (const ", ") (substr (cpos 0) (cpos 4)))
  on "grace hopper" -> " hopper, grac"
Two examples, offset-loving ranker: (concat (substr (after #\space 1) (cpos -1)) (const ", ") (substr (cpos 0) (before #\space 1)))
  on "grace hopper" -> "hopper, grace"
```

With one example, the offset program is just as consistent as the separator program, and only the ranker's taste picks between them. With two examples of different lengths, intersection removes the offset programs, and even the bad ranker has no wrong choice left. Ranking and intersection do the same job from two sides: ranking guesses what the user meant, and each new example cuts down how much guessing is needed.

The same code learns tasks that defeated the toy DSL:

```
=== Format a phone number ===
After 1 example: 4978022400 programs in the version space
  best: (concat (substr (cpos 0) (cpos 3)) (const "-") (substr (cpos 3) (cpos 6)) (const "-") (substr (cpos 6) (cpos -1)))
  "8005550199" -> "800-555-0199"

=== User name from an email address ===
After 1 example: 798964 programs in the version space
  best: (concat (substr (after #\. 1) (before #\@ 1)))
  "ada.lovelace@analytical.uk" -> "lovelace"
After 2 examples: 64 programs in the version space
```

The phone task shows the cost weights at work. A single constant `"-123-"` would also print the middle of the output, but it costs more than a substring between two hyphens, so the ranker reads the digits from the input and the program generalizes.

The last task finds the DSL's edge:

```
=== Initials (beyond this DSL) ===
After 1 example: 72 programs in the version space
  best: (concat (const "g.h."))
  "alan turing" -> "g.h."
After 2 examples: 0 programs in the version space
```

Initials need "the character just after the first space", a position one past a separator. This DSL has no such position, so from one example the best it can do is a constant that does not generalize, and a second example empties the version space. An empty version space is useful output: it tells the user, or the DSL designer, that no program in the language fits. Flash Fill's regex-token positions express "the first character of the second word" directly, which is one reason its DSL is larger than this one.

### Why this is the right shape

The version space algebra gives PBE three properties that the earlier examples lacked:

- **Scale.** The DAG grows with the square of the output length, while the number of programs it holds grows exponentially. The system never enumerates programs.
- **Exact answers to "what else fits?"** The count tells you how ambiguous the examples still are. A system can use that to ask the user for the one example that would cut the space most.
- **Composition by intersection.** Each example builds its own DAG, so examples can arrive in any order, and adding one is a single product construction.

Polozov and Gulwani's FlashMeta framework (now PROSE) generalizes this design: given any DSL with suitable inverse semantics for its operators, it derives the version space construction and intersection automatically.

## Running the Examples

```bash
cd source-code/03-inductive-synthesis-pbe
racket 01-pbe-string-transform.rkt   # whole-string DSL and its limit
racket 02-version-space.rkt          # sequential filter vs intersect
racket 03-genetic-programming.rkt    # subtree mutate/crossover, with x
racket 04-flash-fill-demo.rkt        # Flash Fill framing, toy DSL
racket 05-flash-fill-vsa.rkt         # version space algebra DAGs

# tests (no demo output)
raco test .
```

## Wrap Up

PBE asks the user for the cheapest kind of specification there is, a few examples, and pays for it with ambiguity. This chapter showed the four tools that manage that trade. A DSL bounds what can be learned; the first and fourth examples found its edges. A version space holds every program that fits, and intersection shrinks it as examples arrive. Evolution trades completeness for reach in spaces too big to enumerate. And a version space algebra holds billions of consistent programs in a small DAG, so a ranker can pick the most plausible one and a second example can remove the rest.

The next chapter keeps the same `eval-expr` pattern but turns from examples to specifications: proof extraction, constraint solving, and CEGIS, which adds a verifier that finds the most useful next example on its own.
