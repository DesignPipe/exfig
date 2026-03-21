# PenpotAPI Tests

## E2E Test Data

E2E tests run against a real Penpot instance at `design.penpot.app`.
They are skipped when `PENPOT_ACCESS_TOKEN` is not set.

### Test File

| Field   | Value                                     |
| ------- | ----------------------------------------- |
| Name    | Tokens starter kit                        |
| File ID | `9afc49c1-9c44-8036-8007-bf9fc737a656`    |
| Page ID | `5e5872fb-0776-80fd-8006-154b5dfd6ec7`    |
| Owner   | Aleksei Kakoulin (alexey1312ru@gmail.com) |

### Colors (8)

| Name         | Hex       | Opacity | Path     |
| ------------ | --------- | ------- | -------- |
| Primary      | `#3B82F6` | 1.0     | Brand    |
| Secondary    | `#8B5CF6` | 1.0     | Brand    |
| Success      | `#22C55E` | 1.0     | Semantic |
| Warning      | `#F59E0B` | 1.0     | Semantic |
| Error        | `#EF4444` | 1.0     | Semantic |
| Background   | `#1E1E2E` | 1.0     | Neutral  |
| Text Primary | `#F8F8F2` | 1.0     | Neutral  |
| Overlay      | `#000000` | 0.5     | Neutral  |

### Typographies (4)

| Name        | Font Family | Size | Weight |
| ----------- | ----------- | ---- | ------ |
| Title       | DM Mono     | 30   | 500    |
| Subtitle    | DM Mono     | 24   | 500    |
| Label       | DM Mono     | 16   | 400    |
| Description | DM Mono     | 16   | 400    |

### Components (4)

| Name       | Path      |
| ---------- | --------- |
| IconButton | UI        |
| Avatar     | UI        |
| Badge      | UI/Status |
| Divider    | Layout    |

## Environment Variables

| Variable              | Required | Description                   |
| --------------------- | -------- | ----------------------------- |
| `PENPOT_ACCESS_TOKEN` | Yes      | Penpot personal access token  |
| `PENPOT_TEST_FILE_ID` | No       | Override default test file ID |

## API Path

Tests use `/api/main/methods/` (not `/api/rpc/command/`).
The `rpc` path is blocked by Cloudflare on `design.penpot.app`;
`main/methods` works with `URLSession` and `Accept: application/json`.
