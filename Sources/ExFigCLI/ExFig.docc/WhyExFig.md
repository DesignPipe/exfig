# Why ExFig

Understand the problems ExFig solves and how it fits into your workflow.

## Overview

Design-to-code handoff is broken. Every team that ships a mobile or web app with a Figma or
Penpot-based design system eventually hits the same pain points — and ExFig was built to
eliminate them.

## The Problem

### Manual export doesn't scale

Figma has no "Export to Xcode" button. You open the color picker, copy a hex code, paste it into
a Swift file, repeat for 80 colors, then do it again for dark mode. Icons? Right-click, export SVG,
drag into `.xcassets`, set render mode. Images? Export at @1x, @2x, @3x, rename, organize.
For **one** platform.

### Design and code drift apart

A designer tweaks a brand color. The change sits in Figma until someone notices — or until QA files
a bug. Meanwhile, three platforms show three different shades of blue.

### Multi-platform means multiplied effort

Android needs XML resources and Compose color objects. iOS needs `.xcassets` and SwiftUI extensions.
Flutter needs Dart constants and scaled PNGs. Someone makes all three — by hand, every time.

### Dark mode is an afterthought

Supporting dark mode means doubling every color entry, matching light/dark icon pairs, and generating
separate image variants. Most teams either skip it or maintain fragile scripts.

## Who Is ExFig For?

### iOS Developer

You maintain a design system with 100+ colors and 200+ icons. ExFig reads your Figma file and
generates Color Sets with light/dark/high-contrast variants, PDF vector icons in `.xcassets`,
and type-safe SwiftUI + UIKit extensions — in one command.

### Android Developer

Your team uses Jetpack Compose but the design system still lives in XML `colors.xml`.
ExFig generates both: XML resources for legacy views and Compose `Color` objects with
`VectorDrawable` icons. Android pathData validation catches oversized paths before AAPT does.

### Flutter Developer

You need dark mode icon variants and `@2x`/`@3x` image scales organized in Flutter's asset
directory structure. ExFig exports SVG icons with dark suffixes and raster images with proper
scale directories, plus Dart constants for type-safe access.

### Design Systems Lead

You own one Figma file — or a Penpot project — that feeds four platforms. ExFig's unified
PKL config lets you define the source once and export to iOS, Android, Flutter, and Web from
a single `exfig batch` run. When a designer publishes a library update, one CI pipeline
updates everything. Switching from Figma to Penpot? Change the source in config, keep
everything else.

### CI/CD Engineer

You need deterministic exports that integrate into GitHub Actions. ExFig provides quiet mode,
JSON reports, exit codes, version tracking (skip unchanged files), and checkpoint/resume for
long-running exports. The [GitHub Action](https://github.com/DesignPipe/exfig-action) handles
installation and caching.

## What Gets Generated

### iOS

```
YourProject/
├── Assets.xcassets/
│   ├── Colors/              # Color sets with Light/Dark variants
│   ├── Icons/               # PDF/SVG vector icons
│   └── Images/              # PNG images with @1x, @2x, @3x
└── Sources/
    ├── UIColor+extension.swift      # Type-safe color access
    ├── Color+extension.swift        # SwiftUI colors
    ├── UIImage+extension.swift      # Image access
    ├── UIFont+extension.swift       # Typography
    └── Labels/                      # Pre-configured UILabel classes
```

### Android

```
app/src/main/
├── res/
│   ├── values/
│   │   ├── colors.xml               # Color definitions
│   │   └── typography.xml           # Text styles
│   ├── values-night/
│   │   └── colors.xml               # Dark mode colors
│   ├── drawable/                    # Vector icons/images
│   └── drawable-xxxhdpi/            # Raster images (multiple DPIs)
└── java/.../ui/exfig/
    ├── Colors.kt                    # Compose colors
    ├── Icons.kt                     # Compose icons
    └── Typography.kt                # Compose text styles
```

### Flutter

```
flutter_project/
├── assets/
│   ├── icons/
│   │   ├── ic_add.svg               # Light icons
│   │   └── ic_add_dark.svg          # Dark icons
│   └── images/
│       ├── logo.png                 # 1x scale
│       ├── 2.0x/logo.png            # 2x scale
│       └── 3.0x/logo.png            # 3x scale
└── lib/
    └── generated/
        ├── colors.dart              # Color constants
        ├── icons.dart               # Icon path constants
        └── images.dart              # Image path constants
```

## Before and After

### Before: Manual workflow

1. Designer updates colors in Figma
2. Developer opens Figma, copies hex values one by one
3. Developer updates `colors.xml`, `Colors.xcassets`, and `colors.dart`
4. Developer creates a PR for each platform
5. QA finds the dark mode variant was missed
6. Repeat for 3 platforms, every sprint

### After: `exfig batch`

1. Designer publishes a library update in Figma
2. CI runs `exfig batch exfig.pkl --cache`
3. ExFig detects changed colors, exports only the diff
4. Automated PR with all platforms updated, including dark mode
5. QA verifies — everything matches Figma

## See Also

- <doc:GettingStarted>
- <doc:Configuration>
- <doc:DesignRequirements>
