## Why

Penpot — открытый конкурент Figma с быстро растущей базой пользователей. ExFig уже имеет абстракцию `DesignSource` с `DesignSourceKind.penpot` (объявлен, но не реализован). Добавление Penpot как второго источника данных реализует Фазу 3 ROADMAP.md и подтверждает архитектуру мульти-source.

## What Changes

- Новый модуль `PenpotAPI` — Swift HTTP клиент для Penpot RPC API (аналог `swift-figma-api`)
- `PenpotColorsSource` — загрузка library colors из Penpot файлов
- `PenpotComponentsSource` — загрузка компонентов (иконки, иллюстрации) через thumbnails API
- `PenpotTypographySource` — загрузка типографий из Penpot файлов
- `PenpotColorsConfig` в ExFigCore — type-erased конфиг для Penpot colors
- `PenpotSource` PKL class в Common.pkl — конфигурация Penpot source
- `SourceFactory` — замена `throw unsupportedSourceKind(.penpot)` на реальные реализации
- Env var `PENPOT_ACCESS_TOKEN` для аутентификации
- E2E тесты против реального Penpot instance

**Ограничение v1**: Penpot API не имеет endpoint для рендеринга компонентов в SVG/PNG. Иконки и иллюстрации экспортируются как растровые thumbnails.

## Capabilities

### New Capabilities

- `penpot-api`: HTTP клиент для Penpot RPC API — client, endpoints (`get-file`, `get-profile`, `get-file-object-thumbnails`), response models (Color, Component, Typography, Shape), error handling
- `penpot-source`: Интеграция Penpot с ExFig DesignSource — `PenpotColorsSource`, `PenpotComponentsSource`, `PenpotTypographySource`, `PenpotColorsConfig`, PKL schema, SourceFactory wiring

### Modified Capabilities

- `source-dispatch`: SourceFactory заменяет `throw unsupportedSourceKind(.penpot)` на реальные Penpot source реализации
- `design-source-protocol`: Добавляется `PenpotColorsConfig: ColorsSourceConfig` и spinnerLabel для `.penpot`

## Impact

- **Новый модуль**: `Sources/PenpotAPI/` (~13 файлов), `Tests/PenpotAPITests/`
- **Новые файлы**: `Sources/ExFigCLI/Source/Penpot{Colors,Components,Typography}Source.swift`
- **Изменяемые файлы**: `Package.swift`, `DesignSource.swift`, `ExportContext.swift`, `SourceFactory.swift`, `Common.pkl`
- **Зависимости**: PenpotAPI → swift-yyjson (уже есть). Без новых внешних зависимостей
- **Env vars**: `PENPOT_ACCESS_TOKEN` (required когда sourceKind=penpot), `PENPOT_BASE_URL` (optional)
- **PKL codegen**: `./bin/mise run codegen:pkl` после изменения Common.pkl
- **Entry bridge**: `Sources/ExFig-*/Config/*Entry.swift` — маппинг `penpotSource` полей
