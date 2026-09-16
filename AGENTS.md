# Workflow

This file is the standard operating procedure for coding agents in this project. It sequences external, versioned skills into a single idea → ship pipeline — we don't reimplement them here, we invoke them in order. The skills themselves must already be installed (see the repo README for install commands); this file only tells agents when to reach for each one.

Copy this file (or symlink it) into every project that should follow the same workflow.

`grill-with-docs` is a one-line delegator — it does nothing without `grilling` and `domain-modeling`, so all three must be installed together.

## The spine

Run these in order for any change big enough to warrant planning. Each stage's output is the next stage's input.

1. **`/grill-with-docs`** — Interview a fuzzy idea against the existing domain model. Resolves terminology into `CONTEXT.md` the moment it resolves (not batched), and writes hard-to-reverse decisions to `docs/adr/`. Use for changes that settle in one session; use `/wayfinder` instead for multi-session efforts.
2. **`/to-spec`** — Synthesizes the grilling conversation into a formal spec, published to the issue tracker. No new interview — it uses the shared understanding `/grill-with-docs` already produced.
3. **`/to-tickets`** — Breaks the spec into tickets with explicit blocking edges (which tickets must finish before others can start).
4. **`/implement`** — Executes the tickets. When a ticket touches external data (API responses, DB rows, GraphQL payloads), apply the `mapping-external-data-to-domain-models` pattern: DTOs mirror the wire format, a domain layer holds the app's preferred shape, and pure mapper functions (`toUser()`, etc.) are the only code allowed to import a DTO.
5. **`/code-review`** — Quality gate on the resulting diff.

```
/grill-with-docs → /to-spec → /to-tickets → /implement → /code-review
```

## Cross-cutting

Not pipeline stages — invoke situationally, at any point prose or code is produced:

- **`/unslop`** — Run over any generated prose before it ships: spec text, ADRs, ticket descriptions, PR/commit descriptions, docs. Strips hollow AI phrasing ("highlighting," "ensuring," "Experts believe...") while keeping meaning and tone.
- **`mapping-external-data-to-domain-models`** — The DTO/domain/mapper pattern referenced during `/implement` (see step 4). Also worth a read on its own when designing a new integration.

## Notes

- `grill-with-docs` only produces two kinds of file output: resolved **terms** (→ `CONTEXT.md`, immediately) and hard **decisions** that are surprising, hard to reverse, or involve a real trade-off (→ `docs/adr/`, must clear that bar). Everything else stays in conversation — don't force minor discussion into a permanent file.
- `to-tickets` tickets declare blocking edges — respect them when sequencing `/implement` work; don't start a blocked ticket early.
