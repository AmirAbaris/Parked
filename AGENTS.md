# Workflow

This file is the standard operating procedure for coding agents in this project. It sequences external, versioned skills into a single idea → ship pipeline — we don't reimplement them here, we invoke them in order. The skills themselves must already be installed (see the repo README for install commands); this file only tells agents when to reach for each one.

Copy this file (or symlink it) into every project that should follow the same workflow.

`grill-with-docs` is a one-line delegator — it does nothing without `grilling` and `domain-modeling`, so all three must be installed together.

## The spine

Run these in order for any change big enough to warrant planning. Each stage's output is the next stage's input.

1. **`/grill-with-docs`** — Interview a fuzzy idea against the existing domain model. Resolves terminology into `CONTEXT.md` the moment it resolves (not batched), and writes hard-to-reverse decisions to `docs/adr/`. Use for changes that settle in one session; use `/wayfinder` instead for multi-session efforts.
2. **`/ios-glass-ui-designer`** — For any change to an iOS screen, navigation, or interaction, turn the resolved product intent into an iOS-native screen plan. Define the layout, system components, text hierarchy, interaction states, and the small set of places where glass helps the user understand hierarchy. Do this before writing the spec.
3. **`/to-spec`** — Synthesizes the grilling conversation and the iOS screen plan into a formal spec, published to the issue tracker. No new interview — it uses the shared understanding already produced.
4. **`/to-tickets`** — Breaks the spec into tickets with explicit blocking edges (which tickets must finish before others can start).
5. **`/implement`** — Executes the tickets. When a ticket touches external data (API responses, DB rows, GraphQL payloads), apply the `mapping-external-data-to-domain-models` pattern: DTOs mirror the wire format, a domain layer holds the app's preferred shape, and pure mapper functions (`toUser()`, etc.) are the only code allowed to import a DTO. For iOS 26+ UI work, use `/swiftui-liquid-glass`: prefer standard SwiftUI components, reserve Liquid Glass for navigation and important controls, and use native APIs rather than custom blur effects.
6. **`/code-review`** — Quality gate on the resulting diff. For iOS UI changes, review the result against the screen plan and the Liquid Glass checklist as part of this gate.

```
/grill-with-docs → /ios-glass-ui-designer → /to-spec → /to-tickets → /implement → /code-review
```

## Cross-cutting

Not pipeline stages — invoke situationally, at any point prose or code is produced:

- **`/unslop`** — Run over any generated prose before it ships: spec text, ADRs, ticket descriptions, PR/commit descriptions, docs. Strips hollow AI phrasing ("highlighting," "ensuring," "Experts believe...") while keeping meaning and tone.
- **`mapping-external-data-to-domain-models`** — The DTO/domain/mapper pattern referenced during `/implement` (see step 4). Also worth a read on its own when designing a new integration.
- **`ios-glass-ui-designer`** — Required before specifying a change to an iOS screen or interaction. It produces a native layout and material plan, rather than treating glass as a visual theme.
- **`swiftui-liquid-glass`** — Required when implementing or reviewing iOS 26+ Liquid Glass. Use Apple system components first. Apply custom glass only to controls or navigation, keep it sparse, group nearby effects in `GlassEffectContainer`, and test accessibility settings and fallback behavior.

## Notes

- `grill-with-docs` only produces two kinds of file output: resolved **terms** (→ `CONTEXT.md`, immediately) and hard **decisions** that are surprising, hard to reverse, or involve a real trade-off (→ `docs/adr/`, must clear that bar). Everything else stays in conversation — don't force minor discussion into a permanent file.
- `to-tickets` tickets declare blocking edges — respect them when sequencing `/implement` work; don't start a blocked ticket early.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues. See `docs/agents/issue-tracker.md`.

### Domain docs

Parked uses a single root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md`.
