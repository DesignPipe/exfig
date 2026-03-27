let androidConfigFileContents = #"""
/// ExFig Android configuration.
amends ".exfig/schemas/ExFig.pkl"

import ".exfig/schemas/Figma.pkl"
import ".exfig/schemas/Common.pkl"
import ".exfig/schemas/Android.pkl"

figma = new Figma.FigmaConfig {
  // Identifier of the file containing light color palette, icons and light images.
  // Required for icons, images, typography export. Optional when using only variablesColors for colors.
  // To obtain a file id, open the file in the browser. The file id will be present in the URL after the word file and before the file name.
  lightFileId = "shPilWnVdJfo10YF12345"
  // [optional] Identifier of the file containing dark color palette and dark images.
  darkFileId = "KfF6DnJTWHGZzC912345"
  // [optional] Identifier of the file containing light high contrast color palette.
  // lightHighContrastFileId = "KfF6DnJTWHGZzC912345"
  // [optional] Identifier of the file containing dark high contrast color palette.
  // darkHighContrastFileId = "KfF6DnJTWHGZzC912345"
  // [optional] Figma API request timeout. The default value is 30 (seconds).
  // If you have a lot of resources to export set this value to 60 or more to give Figma API more time to prepare resources for exporting.
  // timeout = 30.0
}

// [optional] Common export parameters
common = new Common.CommonConfig {
  // [optional]
  colors = new Common.Colors {
    // [optional] RegExp pattern for color name validation before exporting.
    // If a name contains "/" symbol it will be replaced by "_" before executing the RegExp.
    nameValidateRegexp = "^([a-zA-Z_]+)$" // RegExp pattern for: background, background_primary, widget_primary_background
    // [optional] RegExp pattern for replacing. Supports only $n
    nameReplaceRegexp = "color_$1"
    // [optional] Extract light and dark mode from the lightFileId using name suffix splitting
    // suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
  // [optional] Use variablesColors instead of colors to export colors from Figma Variables. Cannot be used together with colors.
  // variablesColors = new Common.VariablesColors {
  //   // [required] Identifier of the file containing variables
  //   tokensFileId = "shPilWnVdJfo10YF12345"
  //   // [required] Variables collection name
  //   tokensCollectionName = "Base collection"
  //   // [required] Name of the column containing light color variables in the tokens table
  //   lightModeName = "Light"
  //   // [optional] Name of the column containing dark color variables in the tokens table
  //   darkModeName = "Dark"
  //   // [optional] Name of the column containing light high contrast color variables in the tokens table
  //   lightHCModeName = "Contrast Light"
  //   // [optional] Name of the column containing dark high contrast color variables in the tokens table
  //   darkHCModeName = "Contrast Dark"
  //   // [optional] Name of the column containing color variables in the primitive table. If a value is not specified, the default values will be taken
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
    nameValidateRegexp = "^(ic)_(\\d\\d)_([a-z0-9_]+)$" // RegExp pattern for: ic_24_icon_name, ic_24_icon
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
    nameValidateRegexp = "^(img)_([a-z0-9_]+)$" // RegExp pattern for: img_image_name
    // [optional] RegExp pattern for replacing. Supports only $n
    nameReplaceRegexp = "image_$2"
    // [optional] Extract light and dark mode images from the lightFileId using name suffix splitting
    // suffixDarkMode = new Common.SuffixDarkMode { suffix = "_dark" }
  }
  // [optional]
  typography = new Common.Typography {
    // [optional] RegExp pattern for text style name validation before exporting.
    // If a name contains "/" symbol it will be replaced by "_" before executing the RegExp.
    nameValidateRegexp = "^[a-zA-Z0-9_]+$" // RegExp pattern for: h1_regular, h1_medium
    // [optional] RegExp pattern for replacing. Supports only $n
    nameReplaceRegexp = "font_$1"
  }
}

// [optional] Android export parameters
android = new Android.AndroidConfig {
  // Relative or absolute path to the `main/res` folder including it. The colors/icons/images will be exported to this folder
  mainRes = "./main/res"
  // [optional] The package name, where the android resource constant `R` is located. Must be provided to enable code generation for Jetpack Compose
  resourcePackage = "com.example"
  // [optional] Relative or absolute path to the code source folder including it. The typography for Jetpack Compose will be exported to this folder
  mainSrc = "./main/src/java"
  // [optional] Path to the Jinja2 templates used to generate code
  // templatesPath = "./Resources/Templates"

  // Parameters for exporting colors
  colors = new Android.ColorsEntry {
    // [optional] The package to export the Jetpack Compose color code to. Note: To export Jetpack Compose code, also `mainSrc` and `resourcePackage` above must be set
    composePackageName = "com.example"
    // [optional] File name for XML file with exported colors (default is "colors.xml")
    xmlOutputFileName = "colors.xml"
  }
  // Parameters for exporting icons
  icons = new Android.IconsEntry {
    // Where to place icons relative to `mainRes`? ExFig clears this directory every time you execute `exfig icons` command
    output = "figma-import-icons"
    // [optional] The package to export the Jetpack Compose icon code to. Note: To export Jetpack Compose code, also `mainSrc` and `resourcePackage` above must be set
    composePackageName = "com.example"
    // [optional] Format for Compose icons: "resourceReference" (default) or "imageVector"
    // composeFormat = "resourceReference"
    // [optional] Extension target package for Compose icons
    // composeExtensionTarget = "androidx.compose.ui.graphics.vector.ImageVector"
    // [optional] Package name for Code Connect only (overrides composePackageName for .figma.kt).
    // Use this to generate Code Connect without triggering Icons.kt generation.
    // codeConnectPackageName = "com.example"
    // [optional] Path to generate Figma Code Connect Kotlin file for Jetpack Compose
    // codeConnectKotlin = "./main/src/java/com/example/Icons.figma.kt"
  }
  // Parameters for exporting images
  images = new Android.ImagesEntry {
    // Image file format: svg, png, or webp
    format = "webp"
    // Where to place images relative to `mainRes`? ExFig clears this directory every time you execute `exfig images` command
    output = "figma-import-images"
    // [optional] An array of asset scales that should be downloaded. The valid values are 1 (mdpi), 1.5 (hdpi), 2 (xhdpi), 3 (xxhdpi), 4 (xxxhdpi). The default value is [1, 1.5, 2, 3, 4].
    scales = new Listing { 1.0; 2.0; 3.0 }
    // [optional] Path to generate Figma Code Connect Kotlin file for Jetpack Compose
    // codeConnectKotlin = "./main/src/java/com/example/Images.figma.kt"
    // Format options for webp format only
    webpOptions = new Common.WebpOptions {
      // Encoding type: lossy or lossless
      encoding = "lossy"
      // Encoding quality in percents. Only for lossy encoding.
      quality = 90
    }
  }
  // Parameters for exporting typography
  typography = new Android.Typography {
    // Typography name style: camelCase or snake_case
    nameStyle = "camelCase"
    // [optional] The package to export the Jetpack Compose typography code to. Note: To export Jetpack Compose code, also `mainSrc` and `resourcePackage` above must be set
    composePackageName = "com.example"
  }
}
"""#
