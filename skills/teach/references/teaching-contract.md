# Teach Mode Contract

Teach mode is ON. Explain to build understanding, not to demonstrate coverage.

## Order of explanation (follow this every time)

1. **The problem.** What was painful, broken, or impossible *before* this idea
   existed? Be concrete — name the situation someone was actually stuck in.
   Never open with a definition.
2. **The purpose in one plain sentence.** What is this thing *for*? If the
   sentence needs a technical term to work, the sentence is not ready yet.
3. **A toy example.** The smallest concrete case that still shows the idea.
   Real numbers, real names, small enough to follow by hand. Work it through —
   do not just gesture at it. Strip out every complication that is not the point.
4. **The real thing.** Now map the toy example back onto the actual code,
   paper, or concept at hand. Point at the correspondence explicitly:
   "the `n` in the toy example is the sample size here."
5. **The jargon, last.** Once the shape is understood, attach the technical
   name so it can be recognised in papers, docs, and other people's code.
   "This is what people mean when they say X."

## Language rules

- Short sentences. One idea per sentence.
- Every technical term gets unpacked the first time it appears, in the same
  sentence or the next one. No exceptions, including terms that feel basic.
- No unexplained acronyms. Expand on first use.
- Prefer concrete nouns over abstract ones. "The list of user IDs" beats
  "the collection".
- Analogies are welcome, but label them as analogies and say where they break
  down. An analogy that is not bounded becomes a wrong belief.
- Skip hedging, throat-clearing, and preamble. Start at the problem.

## Anti-patterns

- **Do not** lead with the formal definition and then explain it. That is the
  order that fails.
- **Do not** use a "toy" example that carries real-world complexity. If the
  example needs its own explanation, it is too big.
- **Do not** be condescending. The reader is a working researcher — the goal
  is plain language, not a lowered ceiling. No praise padding, no "great
  question", no exclamation marks.
- **Do not** substitute a list of properties for an explanation of purpose.
  Knowing what something *has* is not knowing what it is *for*.
- **Do not** skip step 1 because the problem seems obvious. It rarely is.

## Scope

Applies to explanations, walkthroughs, code review commentary, and any
description of a method, tool, or concept. It does not change *what* is true —
accuracy, `[UNVERIFIED]` flags, and every other project rule still hold.
