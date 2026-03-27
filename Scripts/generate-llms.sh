#!/bin/bash
# Generate llms.txt and llms-full.txt from project documentation.
# Usage: bash scripts/generate-llms.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GITHUB_BLOB="https://github.com/DesignPipe/exfig/blob/main"
DOCC_BASE="https://designpipe.github.io/exfig/documentation/exfigcli"

LLMS_TXT="${LLMS_TXT:-llms.txt}"
LLMS_FULL="${LLMS_FULL:-llms-full.txt}"

# ── Header (shared) ──────────────────────────────────────────────────────────

HEADER="# ExFig

> Command-line utility to export colors, typography, icons, and images from Figma
> to Xcode, Android Studio, Flutter, and Web (React/TypeScript) projects.
> Supports Dark Mode, SwiftUI, UIKit, Jetpack Compose, Flutter, and React/TypeScript.
> Configuration via PKL. Jinja2 templates for custom code generation."

# ── Document manifest ────────────────────────────────────────────────────────
# Format: file|url|title|description|section|inline
#   inline=1 → content included in llms-full.txt
#   inline=0 → link only in llms.txt

DOCS=(
  # — Documentation —
  "README.md|${GITHUB_BLOB}/README.md|README|Project overview, features, and quick start|Documentation|1"
  "Sources/ExFigCLI/ExFig.docc/GettingStarted.md|${DOCC_BASE}/gettingstarted|Getting Started|Installation, Figma token setup, first export|Documentation|1"
  "Sources/ExFigCLI/ExFig.docc/Usage.md|${DOCC_BASE}/usage|Usage|CLI commands: colors, icons, images, batch, fetch, download|Documentation|1"
  "Sources/ExFigCLI/ExFig.docc/Configuration.md|${DOCC_BASE}/configuration|Configuration|PKL config format, platform entries, variables|Documentation|1"
  "Sources/ExFigCLI/ExFig.docc/DesignRequirements.md|${DOCC_BASE}/designrequirements|Design Requirements|Figma file structure for colors, icons, images|Documentation|1"
  "Sources/ExFigCLI/ExFig.docc/CustomTemplates.md|${DOCC_BASE}/customtemplates|Custom Templates|Jinja2 templates for custom code generation|Documentation|1"

  # — Platform Guides —
  "Sources/ExFigCLI/ExFig.docc/iOS/iOS.md|${DOCC_BASE}/ios|iOS Platform Guide|xcassets, SwiftUI, UIKit, PDF vectors, HEIC|Platform Guides|1"
  "Sources/ExFigCLI/ExFig.docc/Android/Android.md|${DOCC_BASE}/android|Android Platform Guide|XML resources, Compose, Vector Drawables, WebP|Platform Guides|1"
  "Sources/ExFigCLI/ExFig.docc/Flutter/Flutter.md|${DOCC_BASE}/flutter|Flutter Platform Guide|Dart code generation, SVG/PNG assets|Platform Guides|1"

  # — Platform Details (links only) —
  "Sources/ExFigCLI/ExFig.docc/iOS/iOSColors.md|${DOCC_BASE}/ioscolors|iOS Colors|Color sets, SwiftUI extensions, UIKit|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/iOS/iOSIcons.md|${DOCC_BASE}/iosicons|iOS Icons|PDF/SVG icons, xcassets, Swift extensions|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/iOS/iOSImages.md|${DOCC_BASE}/iosimages|iOS Images|Raster images, HEIC, Dark Mode variants|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/iOS/iOSTypography.md|${DOCC_BASE}/iostypography|iOS Typography|Text styles, Dynamic Type, SwiftUI fonts|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/Android/AndroidColors.md|${DOCC_BASE}/androidcolors|Android Colors|XML colors, Compose theme, Material You|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/Android/AndroidIcons.md|${DOCC_BASE}/androidicons|Android Icons|Vector Drawables, Compose ImageVector|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/Android/AndroidImages.md|${DOCC_BASE}/androidimages|Android Images|WebP, drawable resources, density variants|Platform Details|0"
  "Sources/ExFigCLI/ExFig.docc/Android/AndroidTypography.md|${DOCC_BASE}/androidtypography|Android Typography|XML text styles, Compose typography|Platform Details|0"

  # — Reference —
  "docs/PKL.md|${GITHUB_BLOB}/docs/PKL.md|PKL Configuration Guide|In-depth PKL language guide for ExFig configs|Reference|0"
  "CONFIG.md|${GITHUB_BLOB}/CONFIG.md|Full Configuration Reference|Complete field-by-field config reference (all platforms)|Reference|0"
  "docs/ARCHITECTURE.md|${GITHUB_BLOB}/docs/ARCHITECTURE.md|Architecture|Internal module structure and data flow|Reference|0"

  # — Optional —
  "MIGRATION.md|${GITHUB_BLOB}/MIGRATION.md|Migration Guide (v1 → v2)|Breaking changes and upgrade steps|Optional|0"
  "MIGRATION_FROM_FIGMA_EXPORT.md|${GITHUB_BLOB}/MIGRATION_FROM_FIGMA_EXPORT.md|Migration from FigmaExport|Guide for FigmaExport users switching to ExFig|Optional|0"
  "CHANGELOG.md|${GITHUB_BLOB}/CHANGELOG.md|Changelog|Version history and release notes|Optional|0"
  "CONTRIBUTING.md|${GITHUB_BLOB}/CONTRIBUTING.md|Contributing|How to contribute to ExFig|Optional|0"
  "Sources/ExFigCLI/ExFig.docc/Development.md|${DOCC_BASE}/development|Development Guide|Building from source, running tests, project setup|Optional|0"
)

# ── Generate llms.txt ─────────────────────────────────────────────────────────

generate_llms_txt() {
  echo "$HEADER"
  echo ""

  local current_section=""
  for entry in "${DOCS[@]}"; do
    IFS='|' read -r file url title desc section inline <<< "$entry"
    if [[ "$section" != "$current_section" ]]; then
      [[ -n "$current_section" ]] && echo ""
      echo "## $section"
      echo ""
      current_section="$section"
    fi
    echo "- [$title]($url): $desc"
  done
}

# ── Clean DocC / badge markup from content ────────────────────────────────────

clean_content() {
  sed -E \
    -e 's/<doc:([^>]+)>/\1/g' \
    -e '/^@Metadata/,/^}/d' \
    -e '/^@TitleHeading/d' \
    -e '/^\[!\[.*\]\(https:\/\/.*\)\]\(.*\)$/d' \
    -e '/^!\[.*\]\(https:\/\/img\.shields\.io\/.*\)$/d'
}

# ── Generate llms-full.txt ────────────────────────────────────────────────────

generate_llms_full() {
  echo "$HEADER"
  echo ""

  local current_section=""
  for entry in "${DOCS[@]}"; do
    IFS='|' read -r file url title desc section inline <<< "$entry"

    if [[ "$inline" != "1" ]]; then
      continue
    fi

    if [[ ! -f "$file" ]]; then
      echo "WARNING: $file not found, skipping" >&2
      continue
    fi

    if [[ "$section" != "$current_section" ]]; then
      echo "## $section"
      echo ""
      current_section="$section"
    fi

    echo "### $title"
    echo ""
    clean_content < "$file"
    echo ""
  done
}

# ── Main ──────────────────────────────────────────────────────────────────────

generate_llms_txt | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$LLMS_TXT"
generate_llms_full | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$LLMS_FULL"

LINES_TXT=$(wc -l < "$LLMS_TXT" | tr -d ' ')
LINES_FULL=$(wc -l < "$LLMS_FULL" | tr -d ' ')
echo "✓ Generated $LLMS_TXT ($LINES_TXT lines) and $LLMS_FULL ($LINES_FULL lines)"
