# PenpotAPI Module

Standalone HTTP client for Penpot RPC API. Zero dependencies on ExFigCore/ExFigCLI/FigmaAPI.
Only external dependency: swift-yyjson for JSON parsing.

## Architecture

- `PenpotEndpoint` protocol — RPC-style: `POST /api/main/methods/<commandName>`
- `PenpotClient` protocol + `BasePenpotClient` — URLSession, auth, retry
- `PenpotAPIError` — LocalizedError with recovery suggestions
- Models use standard Codable (Penpot JSON is camelCase via `json/write-camel-key` middleware)

## Key Patterns

- All endpoints are POST to `/api/main/methods/<name>` with JSON body
- `Accept: application/json` header (NOT transit+json) — ensures camelCase keys
- `Authorization: Token <accessToken>` header
- Simple retry (3 attempts, exponential backoff) for 429/5xx
- Typography numeric fields may be String OR Number — custom init(from:) handles both

## Conventions

- All model fields are `let` (immutable) — no post-construction mutation needed
- Kebab-case request keys: use `Codable` struct with `CodingKeys` + `YYJSONEncoder`, NOT `JSONSerialization`
- `BasePenpotClient` validates `maxRetries >= 1` and `!accessToken.isEmpty` via preconditions
- Retry loop respects `CancellationError` — rethrows immediately instead of retrying
- `download()` includes response body in error message for diagnostics
