## ADDED Requirements

### Requirement: PenpotAPI module

The system SHALL provide a `PenpotAPI` Swift module with zero dependencies on ExFigCore, ExFigCLI, or FigmaAPI. The only external dependency SHALL be `swift-yyjson` for JSON parsing. The module SHALL be defined as a library target in `Package.swift`.

#### Scenario: PenpotAPI compiles independently

- **WHEN** `PenpotAPI` module is compiled
- **THEN** it SHALL NOT import ExFigCore, ExFigCLI, FigmaAPI, or any platform-specific ExFig module

### Requirement: PenpotEndpoint protocol

The system SHALL define a `PenpotEndpoint` protocol for RPC-style API calls:

```swift
public protocol PenpotEndpoint: Sendable {
    associatedtype Content: Sendable
    var commandName: String { get }
    func body() throws -> Data?
    func content(from data: Data) throws -> Content
}
```

All endpoints SHALL be `POST /api/main/methods/<commandName>` with `Content-Type: application/json` body (the legacy path `/api/rpc/command/<commandName>` is preserved for backward compatibility but the new path is recommended). Response parsing SHALL use `JSONCodec.decode()` from swift-yyjson. All JSON responses use camelCase keys (Penpot backend applies `json/write-camel-key` middleware for `Accept: application/json`).

#### Scenario: Endpoint builds correct URL

- **WHEN** a `PenpotEndpoint` with `commandName = "get-file"` is used
- **THEN** the request URL SHALL be `<baseURL>/api/main/methods/get-file`
- **AND** the HTTP method SHALL be POST

#### Scenario: Endpoint with no body

- **WHEN** a `PenpotEndpoint` returns `nil` from `body()`
- **THEN** the request SHALL have no HTTP body (GET-like behavior over POST)

### Requirement: BasePenpotClient

The system SHALL provide a `BasePenpotClient` conforming to a `PenpotClient` protocol:

```swift
public protocol PenpotClient: Sendable {
    func request<T: PenpotEndpoint>(_ endpoint: T) async throws -> T.Content
}
```

`BasePenpotClient` SHALL:

- Accept `accessToken`, `baseURL` (default `https://design.penpot.app/`), and optional `timeout`
- Use `URLSessionConfiguration.ephemeral` (no caching)
- Set `Authorization: Token <accessToken>` header on all requests
- Set `Accept: application/json` header (NOT `application/transit+json`) — this ensures camelCase keys in responses
- Implement simple retry (3 attempts, exponential backoff) for 429/5xx responses

#### Scenario: Successful authenticated request

- **WHEN** `BasePenpotClient.request()` is called with a valid token
- **THEN** the HTTP request SHALL include `Authorization: Token <token>` header
- **AND** the response SHALL be decoded via the endpoint's `content(from:)` method

#### Scenario: Authentication failure

- **WHEN** Penpot API returns HTTP 401
- **THEN** `BasePenpotClient` SHALL throw `PenpotAPIError` with recovery suggestion mentioning `PENPOT_ACCESS_TOKEN`

#### Scenario: Rate limited response

- **WHEN** Penpot API returns HTTP 429
- **THEN** `BasePenpotClient` SHALL retry after exponential backoff (up to 3 attempts)

#### Scenario: Custom base URL for self-hosted

- **WHEN** `BasePenpotClient` is constructed with `baseURL: "https://penpot.mycompany.com/"`
- **THEN** all requests SHALL use that base URL instead of the default

### Requirement: PenpotAPIError

The system SHALL define a `PenpotAPIError` struct conforming to `LocalizedError` with:

- `statusCode: Int`
- `message: String?`
- `endpoint: String` (command name)
- Recovery suggestions for common errors (401 → auth, 404 → file not found, 429 → rate limited)

#### Scenario: Error includes recovery suggestion

- **WHEN** a `PenpotAPIError` with `statusCode: 401` is created
- **THEN** `recoverySuggestion` SHALL mention checking `PENPOT_ACCESS_TOKEN` environment variable

#### Scenario: Error includes endpoint context

- **WHEN** a `PenpotAPIError` is created for endpoint `"get-file"`
- **THEN** `errorDescription` SHALL include the endpoint name for debugging

### Requirement: GetFileEndpoint

The system SHALL provide a `GetFileEndpoint` that retrieves a complete Penpot file:

- Command: `get-file`
- Body: `{"id": "<file-uuid>"}`
- Response: `PenpotFileResponse` containing `PenpotFileData` with `colors`, `typographies`, `components`

#### Scenario: Get file returns library colors

- **WHEN** `GetFileEndpoint` is called for a file with 5 library colors
- **THEN** the response `data.colors` SHALL contain 5 entries keyed by UUID

#### Scenario: Get file returns components

- **WHEN** `GetFileEndpoint` is called for a file with 3 components
- **THEN** the response `data.components` SHALL contain 3 entries keyed by UUID

#### Scenario: Get file returns typographies

- **WHEN** `GetFileEndpoint` is called for a file with typography styles
- **THEN** the response `data.typographies` SHALL contain entries keyed by UUID

#### Scenario: Get file for nonexistent file

- **WHEN** `GetFileEndpoint` is called with an invalid file UUID
- **THEN** it SHALL throw `PenpotAPIError` with appropriate error message

### Requirement: GetProfileEndpoint

The system SHALL provide a `GetProfileEndpoint` for authentication verification:

- Command: `get-profile`
- Body: none
- Response: `PenpotProfile` with `id`, `fullname`, `email`

#### Scenario: Valid token returns profile

- **WHEN** `GetProfileEndpoint` is called with a valid token
- **THEN** it SHALL return a `PenpotProfile` with non-empty `id`

### Requirement: GetFileObjectThumbnailsEndpoint

The system SHALL provide a `GetFileObjectThumbnailsEndpoint` for component thumbnail retrieval:

- Command: `get-file-object-thumbnails`
- Body: `{"file-id": "<file-uuid>", "object-ids": ["<uuid>", ...]}`
- Response: Dictionary mapping object UUIDs to media IDs or thumbnail URLs

#### Scenario: Thumbnails returned for components

- **WHEN** `GetFileObjectThumbnailsEndpoint` is called with valid component UUIDs
- **THEN** the response SHALL map each UUID to a media ID or thumbnail URL

### Requirement: Asset download

The system SHALL provide a method or endpoint for downloading binary assets:

- URL: `GET <baseURL>/assets/by-file-media-id/<media-id>`
- Response: Binary image data (PNG)
- This is a plain GET request, NOT an RPC command

#### Scenario: Download thumbnail image

- **WHEN** an asset download is requested for a valid media ID
- **THEN** it SHALL return PNG image data
- **AND** the response Content-Type SHALL be an image type

### Requirement: PenpotColor model

The system SHALL define a `PenpotColor` struct:

```swift
public struct PenpotColor: Decodable, Sendable {
    public let id: String
    public let name: String
    public let path: String?
    public let color: String?    // "#RRGGBB" hex
    public let opacity: Double?  // 0.0-1.0
}
```

No custom `CodingKeys` are needed — JSON responses use camelCase keys which match Swift property names. The `path` field uses slash-separated groups (e.g., `"Brand/Primary"`).

#### Scenario: Solid color decoding

- **WHEN** JSON `{"id":"uuid","name":"Blue","color":"#3366FF","opacity":1.0}` is decoded
- **THEN** `PenpotColor.color` SHALL be `"#3366FF"` and `opacity` SHALL be `1.0`

#### Scenario: Color with path

- **WHEN** JSON contains `"path": "Brand/Primary"`
- **THEN** `PenpotColor.path` SHALL be `"Brand/Primary"`

#### Scenario: Gradient color (no solid hex)

- **WHEN** JSON contains a gradient color without `"color"` field
- **THEN** `PenpotColor.color` SHALL be `nil`

### Requirement: PenpotComponent model

The system SHALL define a `PenpotComponent` struct:

```swift
public struct PenpotComponent: Decodable, Sendable {
    public let id: String
    public let name: String
    public let path: String?
    public let mainInstanceId: String?
    public let mainInstancePage: String?
}
```

No custom `CodingKeys` are needed — JSON responses use camelCase keys (`mainInstanceId`, `mainInstancePage`) which match Swift property names.

#### Scenario: Component with path

- **WHEN** JSON contains `"path": "Icons/Navigation"` and `"name": "arrow-right"`
- **THEN** `PenpotComponent.path` SHALL be `"Icons/Navigation"` and `name` SHALL be `"arrow-right"`

#### Scenario: Component with camelCase keys

- **WHEN** JSON contains `"mainInstanceId": "uuid-123"`
- **THEN** `PenpotComponent.mainInstanceId` SHALL be `"uuid-123"`

### Requirement: PenpotTypography model

The system SHALL define a `PenpotTypography` struct with numeric fields that may arrive as either JSON strings or JSON numbers (Clojure schema defines them as strings, but JSON serialization may convert some to numbers):

```swift
public struct PenpotTypography: Decodable, Sendable {
    public let id: String
    public let name: String
    public let path: String?
    public let fontFamily: String
    public let fontStyle: String?
    public let textTransform: String?
    public var fontSize: Double?
    public var fontWeight: Double?
    public var lineHeight: Double?
    public var letterSpacing: Double?
}
```

No custom `CodingKeys` are needed — JSON responses use camelCase keys (`fontFamily`, `fontSize`, `fontWeight`, `lineHeight`, `letterSpacing`, `fontStyle`, `textTransform`) which match Swift property names.

Numeric fields (`fontSize`, `fontWeight`, `lineHeight`, `letterSpacing`) SHALL implement custom `init(from decoder:)` that handles BOTH JSON string values (e.g., `"24"`) AND JSON number values (e.g., `24`). This dual decoding is necessary because Penpot's Clojure schema defines these as strings, but the JSON serialization middleware may convert numeric strings to actual JSON numbers.

#### Scenario: Typography with string numerics

- **WHEN** JSON contains `"fontSize": "24"` and `"fontWeight": "700"`
- **THEN** `fontSize` SHALL return `24.0` and `fontWeight` SHALL return `700.0`

#### Scenario: Typography with JSON number values

- **WHEN** JSON contains `"fontSize": 24` and `"fontWeight": 700` (as JSON numbers)
- **THEN** `fontSize` SHALL return `24.0` and `fontWeight` SHALL return `700.0`

#### Scenario: Typography with unparseable string

- **WHEN** JSON contains `"fontSize": "auto"`
- **THEN** `fontSize` SHALL return `nil` (not crash)

#### Scenario: Typography with camelCase keys

- **WHEN** JSON contains `"fontFamily": "Roboto"`, `"lineHeight": "1.5"`, `"letterSpacing": "0.02"`
- **THEN** all fields SHALL decode correctly via standard Codable synthesis
