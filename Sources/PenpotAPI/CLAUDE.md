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
- `GetProfileEndpoint` sends `{}` body (not nil) — Penpot returns 400 "malformed-json" for empty body

## API Path

Two equivalent paths exist:

- `/api/main/methods/<name>` — **used by this module**; works with URLSession against design.penpot.app
- `/api/rpc/command/<name>` — official docs path; blocked by Cloudflare JS challenge on design.penpot.app for programmatic clients

Self-hosted Penpot instances (without Cloudflare) accept both paths.
If switching to `/api/rpc/command/`, update `BasePenpotClient.buildURL(for:)`.

## Conventions

- All model fields are `let` (immutable) — no post-construction mutation needed
- Kebab-case request keys: use `Codable` struct with `CodingKeys` + `YYJSONEncoder`, NOT `JSONSerialization`
- `BasePenpotClient` validates `maxRetries >= 1` and `!accessToken.isEmpty` via preconditions
- Retry loop respects `CancellationError` — rethrows immediately instead of retrying
- `download()` includes response body in error message for diagnostics
- `performWithRetry` must `throw` on the final attempt for retryable errors — falling through to `return` would return the error response as success data
- `BasePenpotClient.init` validates `baseURL` via precondition — invalid URLs fail at construction, not at first request
- `download(path:)` handles both absolute URLs (`http://...`) and relative paths — does NOT blindly prepend `baseURL`
- `download()` must NOT send `Authorization` header — Penpot assets are served via S3/MinIO presigned URLs that conflict with extra auth
- Thumbnail download path is `assets/by-id/<uuid>`, NOT `assets/by-file-media-id/<uuid>`
- `get-file-object-thumbnails` returns compound keys (`fileId/pageId/objectId/type`), not simple component IDs — v1 limitation

## SVG Reconstruction

Icons/images exported via shape tree → SVG (no CDN, no headless Chrome):

- `PenpotShape.ShapeType` enum (not String) — `.path`, `.rect`, `.circle`, `.group`, `.frame`, `.bool`, `.unknown(String)`. Exhaustive switch in renderer.
- `PenpotComponent.MainInstance` struct pairs `id` + `page`. Backward-compat computed properties `mainInstanceId`/`mainInstancePage`.
- `renderSVGResult()` returns `Result<RenderResult, RenderFailure>` — includes `skippedShapeTypes: Set<String>` and typed failure reasons (`.rootNotFound`, `.missingSelrect`). `renderSVG()` is a convenience wrapper returning `String?`.
- Shapes are in canvas-space — subtract root frame's `selrect.x/y` to normalize
- Arc (`A`) command normalization: 7 params per segment, only params 5 (x) and 6 (y) get origin offset. Tracked via `PathNormState.arcParamIndex`.
- `normalizePathCoordinates` helpers extracted into `PathNormState`, `parseNumber`, `offsetValue` to stay under SwiftLint cyclomatic_complexity/function_body_length limits.
- `svgAttrs` has mixed types (string values + nested `style` dict) — `SVGAttributes` type extracts strings only
- Components need `mainInstanceId` + `mainInstancePage` (via `MainInstance` struct) for shape tree lookup
- Linked libraries: use `get-file` with library file ID (from `get-file-libraries`)
