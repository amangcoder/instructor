# Contributing

## Repository Pattern

All data access in the NestJS server follows the **repository pattern**.

### Rules

1. **All database queries go through repository classes** -- never call `DatabaseService.getDb()` from a service or controller.
2. **`DatabaseService` is infrastructure only** -- it owns the Drizzle connection pool and the `withRetry` circuit breaker. It does not contain business queries.
3. **Repository classes live in `server/src/database/repositories/`** and are registered in `DatabaseModule`.

### Architecture

```
Controller  -->  Service  -->  Repository  -->  DatabaseService.getDb()
```

### Available Repositories

| Repository                 | Domain                        |
|----------------------------|-------------------------------|
| `AuthRepository`           | OTP, refresh tokens           |
| `UserRepository`           | User CRUD                     |
| `PlanRepository`           | Plans, sharing                |
| `TtsRepository`            | TTS jobs, status tracking     |
| `LibraryRepository`        | Library plans                 |
| `SyncRepository`           | Session completions, triggers |
| `AdminRepository`          | Deletion requests             |
| `AdminAnalyticsRepository` | Admin dashboard analytics     |

### Adding a New Repository

1. Create `server/src/database/repositories/<domain>.repository.ts`.
2. Inject `DatabaseService` in the constructor.
3. Register in `DatabaseModule` providers and exports.
4. Export from `server/src/database/repositories/index.ts`.
5. Add a mock factory in `server/src/database/testing/database.service.mock.ts`.

---

## Code Review Checklist

- [ ] **Repository-only data access** -- no `getDb()` calls in services or controllers.
- [ ] **Proper error handling** -- async errors caught, meaningful messages, no swallowed exceptions.
- [ ] **Security** -- inputs validated via DTOs, no internal details leaked in HTTP responses.
- [ ] **Repository mock updated** -- new repository methods have corresponding mock entries.
- [ ] **Existing tests pass** without modification.

---

## Testing

### Centralized Mock Factories

All test mocks live in `server/src/database/testing/`. Import from there instead of defining local mocks.

Available factories:

| Factory                          | Purpose                       |
|----------------------------------|-------------------------------|
| `createMockDatabaseService`      | Mock `DatabaseService`        |
| `createMockAuthRepository`       | Mock `AuthRepository`         |
| `createMockPlanRepository`       | Mock `PlanRepository`         |
| `createMockTtsRepository`        | Mock `TtsRepository`          |
| `createMockUserRepository`       | Mock `UserRepository`         |
| `createMockLibraryRepository`    | Mock `LibraryRepository`      |
| `createMockSyncRepository`       | Mock `SyncRepository`         |
| `createMockAdminRepository`      | Mock `AdminRepository`        |
| `createMockAdminAnalyticsRepository` | Mock `AdminAnalyticsRepository` |

### Example

```typescript
import { createMockDatabaseService, createMockPlanRepository } from '../database/testing';

const mockDb = createMockDatabaseService();
const mockPlanRepo = createMockPlanRepository();
```

When you add a method to a repository, add a matching jest mock to its factory so all consuming tests pick up the change automatically.
