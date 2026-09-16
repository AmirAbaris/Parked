---
name: mapping-external-data-to-domain-models
description: Separates external data shapes (API responses, DB rows, GraphQL payloads) from internal domain models using DTO types plus pure mapper functions. Use when fetching data from an API or database, when a backend response shape (snake_case fields, nested envelopes, provider-specific formats) leaks into frontend or application code, or when the user mentions DTOs, data transfer objects, API boundary mapping, or converting backend responses into app models.
---

# Mapping external data to domain models

Never let an external shape (API response, DB row, third-party SDK type) become your domain model. Define a DTO type that mirrors the wire format exactly, and a pure mapper function that converts it to the shape your application actually wants to work with. Code beyond the mapper never imports the DTO type.

## Core pattern

```typescript
// dto/user.dto.ts — mirrors the API response exactly, including its naming
interface UserDTO {
  first_name: string;
  last_name: string;
}

// domain/user.ts — the shape your app works with
interface User {
  firstName: string;
  lastName: string;
}

// mappers/user.mapper.ts — the only file allowed to import UserDTO
function toUser(dto: UserDTO): User {
  return {
    firstName: dto.first_name,
    lastName: dto.last_name,
  };
}
```

Fetch code calls `toUser(dto)` immediately after receiving the response, then passes `User` everywhere else. If the backend renames a field or restructures its payload, exactly one function needs to change.

## When to apply it — and when not to

Apply this pattern when the external shape is outside your control and likely to drift, or when it's already a poor fit for your domain vocabulary (different naming, units, nesting, or granularity).

Don't reach for it reflexively. A single internal endpoint whose shape already matches what callers want doesn't need a DTO + mapper pair — that's a pass-through layer earning nothing. The signal that it's worth it: either the shape is genuinely foreign (third-party API, legacy DB schema) or you already have more than one source that needs to converge on the same domain type.

## Naming and file layout

Framework- and language-agnostic conventions:

- DTO types live in a `dto/` folder or use a `.dto.ts` suffix — visually distinct from domain types.
- Domain types are plain types/interfaces, named for the concept, colocated with the rest of your domain code (not under `dto/`).
- One mapper function per DTO, named `toX` (`toUser`, `toOrder`). For collections, add `toXList` or map over `toX`.
- Small apps: one `mappers/` folder. Larger apps: colocate each mapper next to the domain type it produces.

## Handling variance

See [EXAMPLES.md](EXAMPLES.md) for worked examples of:
- Nested DTOs (mapping a DTO that contains other DTOs)
- Arrays of DTOs
- Enum/string re-mapping between wire values and domain enums
- Date parsing (ISO string → `Date`)
- Combining multiple DTOs into one aggregate domain object
- The reverse direction: domain → outbound request DTO
- Runtime-validated boundaries (schema validation before mapping)

## Gotchas

- **Mapper drift.** A field gets added or renamed upstream and the mapper silently keeps working with stale data. Build the return object field-by-field rather than spreading (`...dto`) — a spread hides missing/renamed fields instead of surfacing them as a type error. For payloads you don't fully trust, validate with a schema (e.g. zod) before mapping so malformed data fails loud at the boundary, not deep in application logic.
- **DTO leakage.** A DTO type or raw API value sneaks past the mapper into domain logic or UI code. Treat the mapper file as the only legal importer of the DTO type — if another file needs `UserDTO`, that's a sign the boundary moved and the mapper needs to move with it.
- **Undertested mappers.** Mapper functions are pure and cheap to test, but they're also easy to skip because they look trivial. Test them anyway with real edge cases from the actual API: missing optional fields, `null` vs `undefined`, empty arrays, unexpected enum values.
