# mapping-external-data-to-domain-models

An [Agent Skill](https://www.skills.sh) for the DTO-to-domain-model mapping pattern — usable by any coding agent that supports the Agent Skills format (Claude Code, Codex, Cursor, opencode, and others), not tied to one model or tool. It keeps external data shapes (API responses, DB rows, GraphQL payloads) out of your application code by defining a DTO type that mirrors the wire format, plus a pure mapper function that converts it into the shape your app actually wants.

```typescript
// What the backend sends
interface UserDTO {
  first_name: string;
  last_name: string;
}

// What your app works with
interface User {
  firstName: string;
  lastName: string;
}

function toUser(dto: UserDTO): User {
  return { firstName: dto.first_name, lastName: dto.last_name };
}
```

When the backend renames a field or restructures a payload, exactly one function changes — not every call site that touched the old shape.

See [SKILL.md](SKILL.md) for the full pattern (when to use it, naming conventions, common pitfalls) and [EXAMPLES.md](EXAMPLES.md) for worked examples: nested DTOs, arrays, enum re-mapping, dates, combining multiple sources into one domain object, the reverse (domain → outbound request) direction, and schema-validated boundaries.

## File layout

Small/medium apps — one flat `mappers/` folder:

```
src/
├── dto/
│   └── user.dto.ts        # UserDTO
├── domain/
│   └── user.ts             # User
└── mappers/
    └── user.mapper.ts       # toUser()
```

Larger apps — colocate each mapper next to the domain type it produces:

```
src/
└── user/
    ├── user.dto.ts
    ├── user.ts              # domain type
    └── user.mapper.ts       # toUser()
```

Either layout works as long as the mapper file is the only place that imports the DTO type — that's the boundary that actually matters, not the folder shape.

## Install

```bash
npx skills add AmirAbaris/mapping-external-data-to-domain-models
```

Or manually: copy [SKILL.md](SKILL.md) (and [EXAMPLES.md](EXAMPLES.md)) into your agent's skills directory (e.g. `.claude/skills/mapping-external-data-to-domain-models/` for Claude Code, `.agents/skills/...` for others).

## License

MIT — see [LICENSE](LICENSE).
