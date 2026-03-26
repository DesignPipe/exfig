## Context

ExFig v2.8.0 already has a DesignSource abstraction (`ColorsSource`, `ComponentsSource`, `TypographySource` protocols) with `DesignSourceKind.penpot` declared but throwing `unsupportedSourceKind`. The `swift-figma-api` pattern exists — a standalone Swift package with protocol-based client, endpoint structs, and response models.

Penpot uses an **RPC API** (not REST): all calls are `POST /api/main/methods/<name>` with JSON body (the legacy path `/api/rpc/command/<name>` is preserved for backward compatibility). With `Accept: application/json`, responses arrive in **camelCase** (middleware `json/write-camel-key`); kebab-case is preserved only in transit+json. Typography numeric fields are strings in the Clojure schema but may serialize as JSON numbers. There is **no public SVG/PNG export endpoint** — the Penpot exporter uses headless Chromium (internal service); only thumbnails are available via API.

## Goals / Non-Goals

**Goals:**

- PenpotAPI module inside ExFig (extract to `swift-penpot-api` later)
- Basic support: solid colors, icons (thumbnails), illustrations (thumbnails), typography
- E2E tests against a real Penpot instance
- Seamless integration via the existing DesignSource abstraction

**Non-Goals:**

- SVG reconstruction from shape tree (future phase)
- Gradient/image fill colors (v1 — solid only)
- Dark mode for Penpot (Penpot has no mode-based variables like Figma Variables)
- Penpot webhooks / watch mode
- Extraction into a separate repository (after e2e validation)

## Decisions

### D1: RPC endpoint protocol instead of REST

**Decision:** Custom `PenpotEndpoint` protocol, not inheriting from FigmaAPI. URL: `/api/main/methods/<commandName>` (new recommended path).

```swift
protocol PenpotEndpoint: Sendable {
    associatedtype Content: Sendable
    var commandName: String { get }
    func body() throws -> Data?
    func content(from data: Data) throws -> Content
}
```

**Rationale:** Penpot RPC (POST + body) is fundamentally different from Figma REST (GET + path params). A shared endpoint protocol would create a leaky abstraction. When extracted to `swift-penpot-api`, the module ships as-is.

**URL migration:** Penpot migrated from `/api/rpc/command/` to `/api/main/methods/`. The old path is preserved for backward compatibility, but the new one is "strongly recommended". We use the new path by default.

**Alternative:** Generic HTTP endpoint protocol over both APIs — rejected: adds complexity to both clients with no benefit.

### D2: application/json instead of transit+json

**Decision:** `Accept: application/json` header on all requests.

**Rationale:** Transit is a Clojure-specific format with no Swift library. JSON works for all endpoints. The Penpot backend automatically converts keys to camelCase via `json/write-camel-key` middleware when responding with `Accept: application/json`, making responses natively compatible with Swift `Codable`.

**Bug #7540:** Previously, JSON decode failed for files with Design Tokens (missing write handler for `TokensLib` in `clojure.data.json`). The bug was **fixed** (January 2026). We keep a defensive catch for self-hosted instances running older Penpot versions.

**Alternative:** Write a transit parser — rejected: disproportionate effort, and transit preserves kebab-case keys requiring additional mapping.

### D3: Standard Codable without CodingKeys

**Decision:** Models use standard Swift `Codable` synthesis without explicit `CodingKeys`.

**Rationale:** The Penpot backend automatically converts kebab-case keys to camelCase via `json/write-camel-key` middleware when responding with `Accept: application/json`. JSON responses arrive with keys like `fontFamily`, `mainInstanceId`, `fontSize`, etc. — matching standard Swift naming with no mapping required. Confirmed by the official `penpot-export` tool, which works with camelCase without transformation.

**Note:** Kebab-case (`font-family`, `main-instance-id`) is preserved only in `application/transit+json` format, which we do not use (D2).

**Alternative:** Explicit CodingKeys with kebab→camelCase mapping — rejected: unnecessary boilerplate since JSON already arrives in camelCase.

### D4: Client created inside Source, not passed through SourceFactory

**Decision:** `PenpotColorsSource` / `PenpotComponentsSource` create `BasePenpotClient` themselves from env var `PENPOT_ACCESS_TOKEN` and `baseURL` from config.

**Rationale:** Analogous to `TokensFileColorsSource` (does not receive a FigmaAPI Client). Does not require changing the `SourceFactory` signature. The Penpot client is lightweight — 1-3 API calls per export, no benefit from a shared rate limiter.

**Alternative:** Add `penpotClient` to SourceFactory — rejected: breaks the signature, requires client creation even when sourceKind=figma.

### D5: Thumbnails for icons/images (v1)

**Decision:** Use `get-file-object-thumbnails` → `GET /assets/by-file-media-id/<id>` for raster thumbnails.

**Rationale:** Penpot API has no SVG/PNG render endpoint for external consumers. Thumbnails are the only way to obtain a visual representation of a component via API. Suboptimal for icons (raster instead of vector), but works for illustrations.

**Limitation:** Icons will be raster. Warn the user when `format: svg` + `sourceKind: penpot`.

**Future:** SVG reconstruction from shape tree (parse objects → build SVG DOM) — separate phase after e2e validation of the basic flow.

### D6: Reuse IconsSourceInput/ImagesSourceInput fields

**Decision:** For v1 — `figmaFileId` → Penpot file UUID, `frameName` → component path filter. No refactoring to `sourceConfig` pattern.

**Rationale:** Minimal changes to ExFigCore. Refactoring to `ComponentsSourceConfig` (like Colors) — follow-up when a 3rd source appears. Pragmatic approach: field names are not ideal, but types match (String).

### D7: Simple retry instead of SharedRateLimiter

**Decision:** Simple retry (3 attempts, exponential backoff) inside `BasePenpotClient`. No `SharedRateLimiter`.

**Rationale:** Penpot API — 1-3 calls per export (`get-file` returns everything). Rate limits are undocumented. SharedRateLimiter is justified for Figma (dozens of requests, known limits), but overhead for Penpot.

## Risks / Trade-offs

| Risk                                       | Mitigation                                                                 |
| ------------------------------------------ | -------------------------------------------------------------------------- |
| No SVG export → raster icons               | Warn the user. Document the limitation. SVG reconstruction in future phase |
| JSON bug #7540 (Design Tokens)             | Fixed (January 2026). Defensive catch for older self-hosted versions       |
| Penpot API unstable (no versioning)        | E2E tests as canary. Version check via `get-profile`                       |
| Large `get-file` response                  | YYJSON parses efficiently. Decode only needed sections via optional fields |
| String vs Number in typography             | Custom `Codable` init with `decodeIfPresent` for both String and Double    |
| URL migration (`/api/rpc/` → `/api/main/`) | Use new path by default. Old path preserved for backward compatibility     |
| Self-hosted Penpot different versions      | Configurable `baseURL`. E2E against cloud, manual testing for self-hosted  |
