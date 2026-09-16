# Examples

Worked examples for cases beyond the basic flat DTO shown in [SKILL.md](SKILL.md).

## Nested DTOs

```typescript
interface AddressDTO {
  street_line: string;
  postal_code: string;
}

interface UserDTO {
  first_name: string;
  last_name: string;
  address: AddressDTO;
}

interface Address {
  street: string;
  postalCode: string;
}

interface User {
  firstName: string;
  lastName: string;
  address: Address;
}

function toAddress(dto: AddressDTO): Address {
  return {
    street: dto.street_line,
    postalCode: dto.postal_code,
  };
}

function toUser(dto: UserDTO): User {
  return {
    firstName: dto.first_name,
    lastName: dto.last_name,
    address: toAddress(dto.address),
  };
}
```

Each nested DTO gets its own mapper. `toUser` composes `toAddress` rather than inlining the field mapping — keeps each mapper testable on its own.

## Arrays of DTOs

```typescript
function toUserList(dtos: UserDTO[]): User[] {
  return dtos.map(toUser);
}
```

Don't special-case the array version's logic — it should be nothing but a `map` over the single-item mapper. If it needs more than that, the extra logic (dedup, sort, filter) belongs in a separate step after mapping, not inside the mapper.

## Enum / string re-mapping

Wire values and domain enums often don't match 1:1 — the backend may use different casing, legacy values, or values you want to hide behind a stable domain vocabulary.

```typescript
type OrderStatusDTO = "PENDING" | "IN_PROGRESS" | "DONE" | "CANCELLED";

enum OrderStatus {
  Pending = "pending",
  Active = "active",
  Completed = "completed",
  Cancelled = "cancelled",
}

function toOrderStatus(dto: OrderStatusDTO): OrderStatus {
  switch (dto) {
    case "PENDING":
      return OrderStatus.Pending;
    case "IN_PROGRESS":
      return OrderStatus.Active;
    case "DONE":
      return OrderStatus.Completed;
    case "CANCELLED":
      return OrderStatus.Cancelled;
  }
}
```

Using a `switch` without a `default` case means TypeScript flags it as non-exhaustive the moment the backend adds a new status value — that's the point: you want a compile error, not a silently-passed-through unknown string.

## Date parsing

```typescript
interface EventDTO {
  starts_at: string; // ISO 8601 string from the API
}

interface Event {
  startsAt: Date;
}

function toEvent(dto: EventDTO): Event {
  return {
    startsAt: new Date(dto.starts_at),
  };
}
```

Domain code works with `Date` objects (or a date library's type) and never sees the raw ISO string. If the API's date format is unreliable, validate it in the mapper and throw or fall back explicitly — don't let `new Date("garbage")` silently produce an `Invalid Date` that surfaces three layers later.

## Combining multiple DTOs into one aggregate

Sometimes one domain object is assembled from calls to more than one endpoint.

```typescript
interface UserProfileDTO {
  first_name: string;
  last_name: string;
}

interface UserSettingsDTO {
  email_notifications: boolean;
}

interface User {
  firstName: string;
  lastName: string;
  emailNotifications: boolean;
}

function toUser(profile: UserProfileDTO, settings: UserSettingsDTO): User {
  return {
    firstName: profile.first_name,
    lastName: profile.last_name,
    emailNotifications: settings.email_notifications,
  };
}
```

The mapper's signature documents exactly which sources make up the domain object — a caller can see at a glance that building a `User` requires both calls.

## Reverse direction: domain → outbound DTO

The same discipline applies to requests, not just responses. Don't serialize a domain object directly into a request body — map it to a request DTO explicitly.

```typescript
interface UpdateUserRequestDTO {
  first_name: string;
  last_name: string;
}

function toUpdateUserRequestDTO(user: User): UpdateUserRequestDTO {
  return {
    first_name: user.firstName,
    last_name: user.lastName,
  };
}
```

This keeps the outbound wire format decoupled from the domain type in the same way — the domain model can gain fields (e.g. a computed `fullName`) without accidentally being sent to the API.

## Runtime-validated boundary

When the payload isn't fully trusted (third-party API, user-controlled input, a backend team that ships breaking changes without notice), validate before mapping so bad data fails at the boundary with a clear error, instead of producing a malformed domain object.

```typescript
import { z } from "zod";

const UserDTOSchema = z.object({
  first_name: z.string(),
  last_name: z.string(),
});

type UserDTO = z.infer<typeof UserDTOSchema>;

function toUser(raw: unknown): User {
  const dto = UserDTOSchema.parse(raw); // throws with a precise error if shape is wrong
  return {
    firstName: dto.first_name,
    lastName: dto.last_name,
  };
}
```

The schema doubles as the DTO type definition (`z.infer`), so there's no separate hand-written interface to keep in sync with the validator.
