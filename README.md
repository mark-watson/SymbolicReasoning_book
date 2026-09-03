# Book: "Program Synthesis & Symbolic Reasoning: A Foundation for General Intelligence"

## Software examples using Racket Scheme

Companion code and manuscript for the book. Each chapter has complete,
self-contained Racket programs that run on a stock installation with no
external packages.

## Layout

- `manuscript/` — the book text (Leanpub format; `Book.txt` lists chapter order)
- `source-code/NN-chapter-name/` — the runnable example modules for each chapter
- `source-code/utils/` — shared helpers (`string.rkt`, `math.rkt`, `logic.rkt`,
  `eval.rkt`) with `source-code/utils.rkt` as a re-exporting aggregator
- `TOC.md` — the five-part table of contents

## Running the examples

Each example file has demos in `(module+ main ...)` and tests in
`(module+ test ...)`:

```bash
cd source-code/01-introduction-to-symbolic-reasoning
racket 01-propositional-logic.rkt   # run the demo
raco test .                         # run the chapter's checks
```

To run everything at once:

```bash
racket source-code/run-all-tests.rkt   # raco test in every chapter directory
```
