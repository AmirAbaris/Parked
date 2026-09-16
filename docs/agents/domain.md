# Domain docs

How engineering skills should consume Parked's domain documentation.

## Before exploring

Read the root `CONTEXT.md` and relevant ADRs in `docs/adr/` when they exist. If they do not exist, proceed silently. The domain-modeling skill creates them when a term or decision requires them.

## Layout

Parked has one domain context:

```
/
├── CONTEXT.md
└── docs/adr/
```

## Vocabulary

Use terms from `CONTEXT.md` in code, issues, tests, and documentation. Do not replace a defined term with a synonym. Surface any conflict with an ADR instead of silently overriding it.
