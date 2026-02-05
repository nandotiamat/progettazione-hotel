# AGENTS.md - Developer Guide & Rules

This document serves as the primary reference for AI agents and developers working on the `progettazione-hotel` repository.

## 1. Project Overview & Architecture

**Monorepo Structure:**
*   **Root:** `/home/nando/dev/progettazione-hotel`
*   **Frontend:** `app-demo/frontend` (SvelteKit + Svelte 5 + Vite)
*   **Backend:** `app-demo/backend` (FastAPI + Python + SQLAlchemy)

**Key Technologies:**
*   **Frontend:** Svelte 5 (Runes), TypeScript, Vite, Bulma (CSS), Axios.
*   **Backend:** FastAPI, Python 3.x, SQLAlchemy (Sync), Pydantic, AWS boto3.
*   **Database:** PostgreSQL (implied by `psycopg2-binary`).

---

## 2. Build, Lint, and Test Commands

### Frontend (`app-demo/frontend`)
Always ensure `workdir` is set to `app-demo/frontend` or use absolute paths.

*   **Installation:**
    ```bash
    npm install
    ```
*   **Development Server:**
    ```bash
    npm run dev
    ```
*   **Linting & Formatting:**
    ```bash
    npm run lint   # Runs ESLint and Prettier check
    npm run format # Fixes formatting with Prettier
    ```
*   **Type Checking:**
    ```bash
    npm run check
    ```
*   **Testing:**
    *   *Status:* No explicit test runner configured in `package.json`.
    *   *Recommendation:* If adding tests, use **Vitest**.

### Backend (`app-demo/backend`)
Always ensure `workdir` is set to `app-demo/backend` or use absolute paths.

*   **Installation:**
    ```bash
    pip install -r requirements.txt
    ```
*   **Running the App:**
    ```bash
    uvicorn app.main:app --reload
    ```
*   **Testing:**
    *   *Status:* No `tests/` directory found.
    *   *Recommendation:* Use **pytest** if creating tests.
    *   *Command (Hypothetical):* `pytest tests/`
    *   *Single Test:* `pytest tests/test_file.py::test_function_name`
*   **Linting:**
    *   No explicit linter in `requirements.txt`.
    *   *Recommendation:* Use `ruff` or `flake8` if available.

---

## 3. Code Style & Guidelines

### General Conventions
*   **Language:** Code (variable names, functions, classes) must be in **English**.
*   **Comments:** Existing comments are often in **Italian**. Respect existing comments, but write new documentation/comments in English unless context dictates otherwise.
*   **Path Handling:** Always use **absolute paths** when using tools like `read` or `write`. Resolve paths relative to project root.

### Frontend (Svelte 5 + TypeScript)
**CRITICAL: This project uses Svelte 5.**
*   **Runes:** Do NOT use Svelte 4 `export let` or stores (`writable`). Use Runes:
    *   `let count = $state(0);`
    *   `let double = $derived(count * 2);`
    *   `let { propName } = $props();`
*   **Shared State:** Use `.svelte.ts` files with classes or factory functions returning state objects (see `src/lib/state/selection.svelte.ts`).
*   **Imports:** Use the `$lib` alias (e.g., `import { ... } from '$lib/types';`).
*   **API Calls:**
    *   Do not use raw `fetch` or `axios` directly in components.
    *   Use the configured `apiClient` from `$lib/api/client.ts`.
    *   This client automatically handles Auth headers and Token Refresh.
*   **Styling:** The project uses **Bulma** CSS classes.
*   **Naming:** PascalCase for components (`MyComponent.svelte`), camelCase for variables/functions.

### Backend (FastAPI + Python)
*   **Architecture:** Follow the layered Clean Architecture:
    1.  **Routers (`app/routers/`):** Handle HTTP request/response, validation, and Dependency Injection.
    2.  **Services (`app/services/`):** Contains business logic.
    3.  **Repositories (`app/repositories/`):** Handles Database/S3 interactions.
*   **Dependency Injection:**
    *   Use FastAPI `Depends` in route handlers to inject Services.
    *   Services should receive Repositories in `__init__` or methods.
*   **Typing:**
    *   Strict Python type hints are required.
    *   Use `Pydantic` models (from `app/schemas.py`) for Request/Response bodies.
    *   Use `SQLAlchemy` models (from `app/models/`) for DB entities.
*   **Database:**
    *   Use Synchronous SQLAlchemy (`SessionLocal`).
    *   Session is provided via `Depends(get_db)`.
*   **Naming:** snake_case for functions/variables, PascalCase for Classes.

---

## 4. Specific Patterns & Rules

### Authentication
*   **Frontend:** The `apiClient` has an interceptor that attaches `Authorization: Bearer <token>`. It also handles 401 retries by calling `authApi.refreshSession()`.
*   **Backend:** Routes expecting a user should use `current_user: User = Depends(deps.get_current_user)`.

### Error Handling
*   **Backend:** Raise `HTTPException` with appropriate status codes (404, 400, 403) in Routers or Services.
*   **Frontend:** `apiClient` returns Promises. Handle errors in `try/catch` blocks (or `.catch()`).

### File Operations (Agent Rule)
*   **Validation:** Before editing a file, always `read` it first to ensure you have the latest content and correct line numbers.
*   **Safety:** Do not delete files without explicit confirmation.

---

## 5. Directory Map

| Path | Description |
|------|-------------|
| `app-demo/frontend/src/routes/` | SvelteKit Pages and Layouts |
| `app-demo/frontend/src/lib/` | Shared code (API, Utils, Components) |
| `app-demo/frontend/src/lib/state/` | Global State Management (Svelte 5 Runes) |
| `app-demo/backend/app/routers/` | API Endpoints |
| `app-demo/backend/app/services/` | Business Logic |
| `app-demo/backend/app/repositories/` | Data Access Layer |
| `app-demo/backend/app/models/` | DB Models (SQLAlchemy) |
| `app-demo/backend/app/schemas.py` | Pydantic Models (DTOs) |
