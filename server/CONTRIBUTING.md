# Contributing — Server

## Repository-Pattern Guidelines

### Overview

All database access in the NestJS server follows the **repository pattern**.
Business-layer services (controllers, services) must **never** call
`DatabaseService.getDb()` directly. Instead, they inject a domain-specific
repository that encapsulates all raw Drizzle/SQL queries.

### Architecture

```
Controller  -->  Service  -->  Repository  -->  DatabaseService.getDb()
```

- **`DatabaseService`** — owns the Drizzle instance and connection lifecycle.
  Only repositories (and `DatabaseService` itself) may call `getDb()`.
- **Repositories** (`server/src/database/repositories/`) — thin data-access
  classes that wrap Drizzle queries behind typed async methods.
- **Services** — contain business logic and call repository methods.

### Existing Repositories

| Repository                | Domain                         |
|---------------------------|--------------------------------|
| `AuthRepository`          | OTP, refresh tokens            |
| `UserRepository`          | User CRUD                      |
| `PlanRepository`          | Plans, sharing                 |
| `TtsRepository`           | TTS jobs, status tracking      |
| `LibraryRepository`       | Library plans                  |
| `SyncRepository`          | Session completions, triggers  |
| `AdminRepository`         | Deletion requests              |
| `AdminAnalyticsRepository`| Admin dashboard analytics      |

### Adding a New Repository

1. Create `server/src/database/repositories/<domain>.repository.ts`.
2. Inject `DatabaseService` in the constructor.
3. Add the repository to `DatabaseModule` providers and exports.
4. Export from `server/src/database/repositories/index.ts`.
5. Add a mock factory to `server/src/database/testing/database.service.mock.ts`.

### Injecting Repositories in Services

Use `@Optional() @Inject()` for backward compatibility with tests that do not
provide the repository:

```typescript
import { Optional, Inject } from '@nestjs/common';
import { PlanRepository } from '../database/repositories/plan.repository';

@Injectable()
export class PlansService {
  private readonly plans: PlanRepository | DatabaseService;

  constructor(
    private readonly db: DatabaseService,
    @Optional() @Inject(PlanRepository) planRepo?: PlanRepository,
  ) {
    this.plans = planRepo ?? db;
  }

  async getPlan(id: string) {
    return this.plans.getPlanById(id);  // NOT this.db.getDb()
  }
}
```

### Code Review Checklist

- [ ] No `getDb()` calls in service or controller files
- [ ] New queries added to the appropriate repository
- [ ] Repository mock factory updated in `database.service.mock.ts`
- [ ] Existing tests pass without modification
- [ ] New repository methods have matching mock entries
