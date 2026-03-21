## Context

ExFig v2.8.0 уже имеет абстракцию DesignSource (`ColorsSource`, `ComponentsSource`, `TypographySource` протоколы) с `DesignSourceKind.penpot` объявленным, но выбрасывающим `unsupportedSourceKind`. Существует паттерн `swift-figma-api` — standalone Swift package с protocol-based client, endpoint structs, и response models.

Penpot использует **RPC API** (не REST): все вызовы — `POST /api/rpc/command/<name>` с JSON body. Ключи в JSON — kebab-case. Числа в типографии — строки. SVG/PNG export endpoint **отсутствует** — только thumbnails через `get-file-object-thumbnails`.

## Goals / Non-Goals

**Goals:**

- PenpotAPI модуль внутри ExFig (позже извлечь в `swift-penpot-api`)
- Базовая поддержка: solid colors, icons (thumbnails), illustrations (thumbnails), typography
- E2E тесты против реального Penpot instance
- Бесшовная интеграция через существующую DesignSource абстракцию

**Non-Goals:**

- SVG reconstruction из shape tree (future phase)
- Gradient/image fill colors (v1 — только solid)
- Dark mode для Penpot (Penpot не имеет mode-based переменных как Figma Variables)
- Penpot webhooks / watch mode
- Извлечение в отдельный репозиторий (делаем после e2e)

## Decisions

### D1: RPC endpoint protocol вместо REST

**Решение:** Собственный `PenpotEndpoint` protocol, не наследующий от FigmaAPI.

```swift
protocol PenpotEndpoint: Sendable {
    associatedtype Content: Sendable
    var commandName: String { get }
    func body() throws -> Data?
    func content(from data: Data) throws -> Content
}
```

**Почему:** Penpot RPC (POST + body) фундаментально отличается от Figma REST (GET + path params). Общий endpoint protocol создал бы leaky abstraction. При извлечении в `swift-penpot-api` модуль поедет as-is.

**Альтернатива:** Generic HTTP endpoint protocol поверх обоих API → отклонено: усложняет оба клиента без выгоды.

### D2: application/json вместо transit+json

**Решение:** `Accept: application/json` header во всех запросах.

**Почему:** Transit — Clojure-specific формат без Swift библиотеки. JSON работает для всех endpoint'ов. Известный баг #7540 (JSON decode fails для файлов с Design Tokens) — edge case, обрабатываем понятной ошибкой.

**Альтернатива:** Написать transit parser → отклонено: непропорциональные затраты для edge case.

### D3: Явные CodingKeys вместо key strategy

**Решение:** Каждая модель имеет `enum CodingKeys: String, CodingKey` с маппингом kebab→camelCase.

**Почему:** YYJSON (swift-yyjson) — primary JSON decoder в проекте. `JSONCodec.decode()` может не поддерживать custom key strategies. Explicit CodingKeys — паттерн из FigmaAPI для snake_case. Моделей ~6 — overhead минимальный.

**Альтернатива:** `JSONDecoder.keyDecodingStrategy = .custom` → отклонено: несовместимо с JSONCodec/YYJSON.

### D4: Клиент создаётся внутри Source, не передаётся через SourceFactory

**Решение:** `PenpotColorsSource` / `PenpotComponentsSource` сами создают `BasePenpotClient` из env var `PENPOT_ACCESS_TOKEN` и `baseURL` из config.

**Почему:** Аналог `TokensFileColorsSource` (не получает FigmaAPI Client). Не требует изменения сигнатуры `SourceFactory`. Penpot client лёгкий — 1-3 API вызова на экспорт, нет смысла в shared rate limiter.

**Альтернатива:** Добавить `penpotClient` в SourceFactory → отклонено: ломает сигнатуру, требует создание клиента даже когда sourceKind=figma.

### D5: Thumbnails для icons/images (v1)

**Решение:** Использовать `get-file-object-thumbnails` → `GET /assets/by-file-media-id/<id>` для растровых thumbnails.

**Почему:** Penpot API не имеет SVG/PNG render endpoint. Thumbnails — единственный способ получить визуальное представление компонента через API. Для иконок это субоптимально (растр вместо вектора), но работает для иллюстраций.

**Ограничение:** Иконки будут растровые. Warn пользователя при `format: svg` + `sourceKind: penpot`.

**Future:** SVG reconstruction из shape tree (parse objects → build SVG DOM) — отдельная фаза после e2e валидации базового flow.

### D6: Переиспользование полей IconsSourceInput/ImagesSourceInput

**Решение:** Для v1 — `figmaFileId` → Penpot file UUID, `frameName` → component path filter. Без рефакторинга на `sourceConfig` pattern.

**Почему:** Минимальные изменения в ExFigCore. Рефакторинг на `ComponentsSourceConfig` (как у Colors) — follow-up, когда появится 3-й source. Прагматичный подход: имена полей неидеальные, но типы совпадают (String).

### D7: Простой retry вместо SharedRateLimiter

**Решение:** Простой retry (3 попытки, exponential backoff) внутри `BasePenpotClient`. Без `SharedRateLimiter`.

**Почему:** Penpot API — 1-3 вызова на экспорт (`get-file` возвращает всё). Rate limits не задокументированы. SharedRateLimiter оправдан для Figma (десятки запросов, известные лимиты), но overhead для Penpot.

## Risks / Trade-offs

| Risk                                        | Mitigation                                                                        |
| ------------------------------------------- | --------------------------------------------------------------------------------- |
| Нет SVG export → иконки растровые           | Warn пользователя. Документировать ограничение. SVG reconstruction в future phase |
| JSON bug #7540 (Design Tokens)              | Catch decode error → понятное сообщение с workaround                              |
| Penpot API нестабилен (нет версионирования) | E2E тесты как canary. Version check через `get-profile`                           |
| Большой `get-file` response                 | YYJSON эффективно парсит. Декодируем только нужные секции через optional поля     |
| String numerics в типографии                | `Double(string)` с guard + warning, never force-unwrap                            |
| Kebab-case → CodingKeys boilerplate         | ~6 моделей, терпимо. При извлечении в пакет — один раз написать                   |
| Self-hosted Penpot разные версии            | Configurable `baseURL`. E2E против cloud, manual testing для self-hosted          |
