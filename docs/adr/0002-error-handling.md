# 2. Result type and a single error funnel

Status: Accepted · Date: 2026-10-11

## Context
The backend is ASP.NET Core, which returns RFC 9457 ProblemDetails. Errors must never leak raw backend English to Arabic users, and nothing may be swallowed silently.

## Decision
- Repositories and use cases return `Result<T>` (`Ok` / `Err`), never throw.
- `ApiClient` is the only HTTP entry point: non-2xx → `ApiException` (parsed ProblemDetails), no response → `NetworkException`.
- `*RepositoryImpl` wraps calls in `guard()`, which calls `FailureMapper.fromError()` exactly once.
- `Failure` is a sealed type without localization; presentation translates it with `FailureL10n.localizedMessage`.
- Expected API/network errors become log breadcrumbs; unexpected errors are logged with their stack trace.

## Consequences
Every status code has a translated message. Endpoint-specific meanings (e.g. 401 on login) are handled in that repository before the generic mapping.
