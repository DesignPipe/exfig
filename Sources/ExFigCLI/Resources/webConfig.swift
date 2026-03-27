let webConfigFileContents = #"""
/// ExFig Web configuration.
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/Web.pkl"

figma = new Figma.FigmaConfig {
  // Identifier of the file containing light color palette, icons and light images.
  // Required for icons, images, typography export. Optional when using only variablesColors for colors.
  // To obtain a file id, open the file in the browser.
  // The file id will be present in the URL after the word file and before the file name.
  lightFileId = "shPilWnVdJfo10YF12345"
  // [optional] Identifier of the file containing dark color palette and dark images.
  darkFileId = "KfF6DnJTWHGZzC912345"
  // [optional] Figma API request timeout. The default value is 30 (seconds).
  // If you have a lot of resources to export set this value to 60 or more.
  // timeout = 30.0
}

// [optional] Common export parameters
common = new Common.CommonConfig {
  // [optional]
  colors = new Common.Colors {
    // [optional] RegExp pattern for color name validation before exporting.
    // If a name contains "/" symbol it will be replaced by "_" before executing the RegExp.
    nameValidateRegexp = "^([a-zA-Z_]+)$"
    // [optional] RegExp pattern for replacing. Supports only $n
    nameReplaceRegexp = "color_$1"
    // [optional] Extract light and dark mode from the lightFileId using name suffix splitting
    // suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
  // [optional] Use variablesColors to export colors from Figma Variables.
  // variablesColors = new Common.VariablesColors {
  //   // [required] Identifier of the file containing variables
  //   tokensFileId = "shPilWnVdJfo10YF12345"
  //   // [required] Variables collection name
  //   tokensCollectionName = "Base collection"
  //   // [required] Name of the column containing light color variables in the tokens table
  //   lightModeName = "Light"
  //   // [optional] Name of the column containing dark color variables in the tokens table
  //   darkModeName = "Dark"
  //   // [optional] Name of the column containing color variables in the primitive table.
  //   primitivesModeName = "Collection_1"
  //   // [optional] RegExp pattern for color name validation before exporting.
  //   nameValidateRegexp = "^([a-zA-Z_]+)$"
  //   // [optional] RegExp pattern for replacing. Supports only $n
  //   nameReplaceRegexp = "color_$1"
  // }
  // [optional]
  icons = new Common.Icons {
    // [optional] Name of the Figma's frame where icons components are located
    figmaFrameName = "Icons"
    // [optional] Name of the Figma page to filter icons by (useful when multiple pages share the same frame name)
    // figmaPageName = "Outlined"
    // [optional] RegExp pattern for icon name validation before exporting.
    // If a name contains "/" symbol it will be replaced by "_" before executing the RegExp.
    nameValidateRegexp = "^(ic)_(\\d\\d)_([a-z0-9_]+)$"
    // [optional] RegExp pattern for replacing. Supports only $n
    nameReplaceRegexp = "icon_$2_$1"
    // [optional] Extract light and dark mode icons from the lightFileId using name suffix splitting
    // suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
  // [optional]
  images = new Common.Images {
    // [optional] Name of the Figma's frame where image components are located
    figmaFrameName = "Illustrations"
    // [optional] Name of the Figma page to filter images by (useful when multiple pages share the same frame name)
    // figmaPageName = "Marketing"
    // [optional] RegExp pattern for image name validation before exporting.
    // If a name contains "/" symbol it will be replaced by "_" before executing the RegExp.
    nameValidateRegexp = "^(img)_([a-z0-9_]+)$"
    // [optional] RegExp pattern for replacing. Supports only $n
    nameReplaceRegexp = "image_$2"
    // [optional] Extract light and dark mode images from the lightFileId using name suffix splitting
    // suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
}

// Web/React export parameters
web = new Web.WebConfig {
  // Output directory for generated TypeScript/CSS files
  output = "./src/tokens"
  // [optional] Path to the Jinja2 templates used to generate code
  // templatesPath = "./Resources/Templates"

  // Parameters for exporting colors
  colors = new Web.ColorsEntry {
    // [optional] Output directory for color files (overrides web.output)
    outputDirectory = "."
    // [optional] CSS file name for theme variables
    cssFileName = "theme.css"
    // [optional] TypeScript file name for CSS variable references
    tsFileName = "variables.ts"
    // [optional] JSON file name for design tokens (useful for tooling integration)
    // jsonFileName = "tokens.json"
  }

  // Parameters for exporting icons
  icons = new Web.IconsEntry {
    // Output directory for React icon components
    outputDirectory = "./src/icons"
    // [optional] Directory for raw SVG files
    svgDirectory = "assets/icons"
    // [optional] Generate React TSX components (default: true)
    generateReactComponents = true
  }

  // Parameters for exporting images
  images = new Web.ImagesEntry {
    // Output directory for image components
    outputDirectory = "./src/images"
    // [optional] Directory for raw image assets
    assetsDirectory = "assets/images"
    // [optional] Generate React TSX components (default: true)
    generateReactComponents = true
  }
}
"""#
