param(
  [string]$OutputDirectory = '',
  [string]$RenderDirectory = ''
)

$ErrorActionPreference = 'Stop'

$root = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  (Get-Location).Path
} else {
  Split-Path -Parent $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $root 'docs\presentations'
}
if ([string]::IsNullOrWhiteSpace($RenderDirectory)) {
  $RenderDirectory = Join-Path $root '.checks\presentation-render'
}
$logoPath = Join-Path $root 'LibeRation\inst\assets\favicon.svg'
$templatePath = Join-Path $OutputDirectory 'LibeR_Branded_Template.potx'
$deckPath = Join-Path $OutputDirectory 'LibeR_University_Presentation.pptx'

if (-not (Test-Path -LiteralPath $logoPath)) {
  throw "LibeR logo not found: $logoPath"
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $RenderDirectory -Force | Out-Null
foreach ($generatedFile in @($templatePath, $deckPath)) {
  if (Test-Path -LiteralPath $generatedFile) { Remove-Item -LiteralPath $generatedFile -Force }
}
Get-ChildItem -LiteralPath $RenderDirectory -File -ErrorAction SilentlyContinue | Remove-Item -Force

# Office constants kept local so the script is self-contained.
$msoFalse = 0
$msoTrue = -1
$msoTextOrientationHorizontal = 1
$msoShapeRectangle = 1
$msoShapeRoundedRectangle = 5
$msoShapeOval = 9
$msoConnectorStraight = 1
$msoArrowheadTriangle = 3
$msoAnchorTop = 1
$msoAnchorMiddle = 3
$msoAlignLeft = 1
$msoAlignCenter = 2
$msoAlignRight = 3
$ppPlaceholderTitle = 1
$ppPlaceholderBody = 2
$ppPlaceholderCenterTitle = 3
$ppPlaceholderSubtitle = 4
$ppSaveAsOpenXMLPresentation = 24
$ppSaveAsOpenXMLTemplate = 26

$script:SlideWidth = 960.0
$script:SlideHeight = 540.0
$script:FontDisplay = 'Aptos Display'
$script:FontBody = 'Aptos'
$script:FontMono = 'Consolas'

$script:Colors = @{
  Navy = '#23384D'
  Blue = '#4D7FA8'
  Green = '#3F7D68'
  Red = '#B33B45'
  Orange = '#A37232'
  Purple = '#66558D'
  Teal = '#28777B'
  Dark = '#111820'
  DarkSurface = '#19232D'
  Light = '#F1F4F6'
  Surface = '#FFFFFF'
  Surface2 = '#F7F8FA'
  Text = '#1F2B36'
  Muted = '#65727E'
  Line = '#CCD5DC'
  PaleBlue = '#E7EFF5'
  PaleGreen = '#E6F0EC'
  PaleTeal = '#E5F0F0'
  PalePurple = '#ECE9F2'
  PaleOrange = '#F4EEE5'
  White = '#FFFFFF'
}

function Convert-HexToOfficeColor {
  param([Parameter(Mandatory = $true)][string]$Hex)
  $value = $Hex.TrimStart('#')
  if ($value.Length -ne 6) { throw "Expected a six-digit colour: $Hex" }
  $r = [Convert]::ToInt32($value.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($value.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($value.Substring(4, 2), 16)
  return $r + (256 * $g) + (65536 * $b)
}

function Set-Fill {
  param($Shape, [string]$Color, [double]$Transparency = 0)
  $Shape.Fill.Visible = $msoTrue
  $Shape.Fill.Solid()
  $Shape.Fill.ForeColor.RGB = Convert-HexToOfficeColor $Color
  $Shape.Fill.Transparency = $Transparency
}

function Set-Line {
  param($Shape, [string]$Color, [double]$Weight = 1, [double]$Transparency = 0)
  $Shape.Line.Visible = $msoTrue
  $Shape.Line.ForeColor.RGB = Convert-HexToOfficeColor $Color
  $Shape.Line.Weight = $Weight
  $Shape.Line.Transparency = $Transparency
}

function Add-Rectangle {
  param(
    $Shapes,
    [double]$X, [double]$Y, [double]$Width, [double]$Height,
    [string]$Fill,
    [string]$Line = '',
    [double]$Radius = 0,
    [double]$Transparency = 0,
    [double]$LineWeight = 1
  )
  $shapeType = if ($Radius -gt 0) { $msoShapeRoundedRectangle } else { $msoShapeRectangle }
  $shape = $Shapes.AddShape($shapeType, $X, $Y, $Width, $Height)
  Set-Fill $shape $Fill $Transparency
  if ([string]::IsNullOrWhiteSpace($Line)) {
    $shape.Line.Visible = $msoFalse
  } else {
    Set-Line $shape $Line $LineWeight 0
  }
  return $shape
}

function Add-Circle {
  param(
    $Shapes,
    [double]$X, [double]$Y, [double]$Diameter,
    [string]$Fill,
    [string]$Line = '',
    [double]$Transparency = 0
  )
  $shape = $Shapes.AddShape($msoShapeOval, $X, $Y, $Diameter, $Diameter)
  Set-Fill $shape $Fill $Transparency
  if ([string]::IsNullOrWhiteSpace($Line)) { $shape.Line.Visible = $msoFalse } else { Set-Line $shape $Line 1 0 }
  return $shape
}

function Add-Text {
  param(
    $Shapes,
    [string]$Text,
    [double]$X, [double]$Y, [double]$Width, [double]$Height,
    [double]$Size = 18,
    [string]$Color = '#1F2B36',
    [bool]$Bold = $false,
    [string]$Font = 'Aptos',
    [int]$Alignment = 1,
    [int]$VerticalAnchor = 1,
    [double]$Margin = 0,
    [bool]$Wrap = $true
  )
  $shape = $Shapes.AddTextbox($msoTextOrientationHorizontal, $X, $Y, $Width, $Height)
  $shape.Fill.Visible = $msoFalse
  $shape.Line.Visible = $msoFalse
  $shape.TextFrame2.MarginLeft = $Margin
  $shape.TextFrame2.MarginRight = $Margin
  $shape.TextFrame2.MarginTop = $Margin
  $shape.TextFrame2.MarginBottom = $Margin
  $shape.TextFrame2.VerticalAnchor = $VerticalAnchor
  $shape.TextFrame2.WordWrap = if ($Wrap) { $msoTrue } else { $msoFalse }
  $shape.TextFrame2.TextRange.Text = $Text
  $shape.TextFrame2.TextRange.Font.Name = $Font
  $shape.TextFrame2.TextRange.Font.Size = $Size
  $shape.TextFrame2.TextRange.Font.Bold = if ($Bold) { $msoTrue } else { $msoFalse }
  $shape.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = Convert-HexToOfficeColor $Color
  $shape.TextFrame2.TextRange.ParagraphFormat.Alignment = $Alignment
  return $shape
}

function Add-Connector {
  param(
    $Shapes,
    [double]$X1, [double]$Y1, [double]$X2, [double]$Y2,
    [string]$Color = '#4D7FA8',
    [double]$Weight = 2,
    [bool]$Arrow = $true,
    [bool]$Dashed = $false
  )
  $line = $Shapes.AddConnector($msoConnectorStraight, $X1, $Y1, $X2, $Y2)
  Set-Line $line $Color $Weight 0
  if ($Arrow) { $line.Line.EndArrowheadStyle = $msoArrowheadTriangle }
  if ($Dashed) { $line.Line.DashStyle = 4 }
  return $line
}

function Add-LogoWordmark {
  param($Shapes, [double]$X, [double]$Y, [double]$IconSize, [string]$WordColor)
  $picture = $Shapes.AddPicture($logoPath, $msoFalse, $msoTrue, $X, $Y, $IconSize, $IconSize)
  $word = Add-Text $Shapes 'LibeR' ($X + $IconSize + 8) ($Y + 1) 110 ($IconSize - 1) ([Math]::Max(17, $IconSize * 0.58)) $WordColor $true $script:FontDisplay $msoAlignLeft $msoAnchorMiddle 0 $false
  return @($picture, $word)
}

function Add-Card {
  param(
    $Shapes,
    [double]$X, [double]$Y, [double]$Width, [double]$Height,
    [string]$Fill = '#FFFFFF',
    [string]$Line = '#CCD5DC',
    [double]$Radius = 8
  )
  $card = Add-Rectangle $Shapes $X $Y $Width $Height $Fill $Line $Radius 0 0.85
  $card.Shadow.Visible = $msoTrue
  $card.Shadow.Blur = 4
  $card.Shadow.OffsetX = 0
  $card.Shadow.OffsetY = 2
  $card.Shadow.Transparency = 0.82
  return $card
}

function Add-Pill {
  param(
    $Shapes,
    [string]$Text,
    [double]$X, [double]$Y, [double]$Width, [double]$Height,
    [string]$Fill,
    [string]$Color,
    [double]$Size = 12
  )
  Add-Rectangle $Shapes $X $Y $Width $Height $Fill '' 10 | Out-Null
  return Add-Text $Shapes $Text $X $Y $Width $Height $Size $Color $true $script:FontBody $msoAlignCenter $msoAnchorMiddle 5 $true
}

function Style-Placeholder {
  param($Shape, [double]$Size, [string]$Color, [bool]$Bold, [string]$Font)
  $Shape.TextFrame2.MarginLeft = 0
  $Shape.TextFrame2.MarginRight = 0
  $Shape.TextFrame2.MarginTop = 0
  $Shape.TextFrame2.MarginBottom = 0
  $Shape.TextFrame2.TextRange.Font.Name = $Font
  $Shape.TextFrame2.TextRange.Font.Size = $Size
  $Shape.TextFrame2.TextRange.Font.Bold = if ($Bold) { $msoTrue } else { $msoFalse }
  $Shape.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = Convert-HexToOfficeColor $Color
}

function Clear-LayoutShapes {
  param($Layout)
  for ($index = $Layout.Shapes.Count; $index -ge 1; $index--) {
    $Layout.Shapes.Item($index).Delete()
  }
}

function Add-LightLayoutChrome {
  param($Layout)
  Add-Rectangle $Layout.Shapes 0 0 $script:SlideWidth $script:SlideHeight $script:Colors.Light | Out-Null
  Add-Rectangle $Layout.Shapes 0 0 12 $script:SlideHeight $script:Colors.Blue | Out-Null
  Add-LogoWordmark $Layout.Shapes 42 24 29 $script:Colors.Navy | Out-Null
  $line = $Layout.Shapes.AddLine(42, 510, 918, 510)
  Set-Line $line $script:Colors.Line 0.8 0
  Add-Text $Layout.Shapes 'LibeR ecosystem' 42 514 180 16 9 $script:Colors.Muted $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
}

function Add-DarkLayoutChrome {
  param($Layout)
  Add-Rectangle $Layout.Shapes 0 0 $script:SlideWidth $script:SlideHeight $script:Colors.Dark | Out-Null
  Add-Circle $Layout.Shapes 760 -110 310 $script:Colors.Blue '' 0.82 | Out-Null
  Add-Circle $Layout.Shapes 820 390 180 $script:Colors.Teal '' 0.76 | Out-Null
  Add-LogoWordmark $Layout.Shapes 48 30 36 $script:Colors.White | Out-Null
}

function Add-SlideTitle {
  param($Slide, [string]$Title, [string]$Subtitle = '')
  Add-Text $Slide.Shapes $Title 43 65 870 40 27 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
    Add-Text $Slide.Shapes $Subtitle 44 105 870 28 13 $script:Colors.Muted $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  }
}

function Add-SlideNumber {
  param($Slide, [int]$Number, [string]$Color = '#65727E')
  Add-Text $Slide.Shapes ([string]$Number) 890 514 28 16 9 $Color $true $script:FontBody $msoAlignRight $msoAnchorTop 0 $false | Out-Null
}

function Add-LabelValueRow {
  param(
    $Shapes,
    [string]$Label,
    [string]$Value,
    [double]$X, [double]$Y, [double]$Width,
    [string]$Accent
  )
  Add-Circle $Shapes $X ($Y + 6) 10 $Accent | Out-Null
  Add-Text $Shapes $Label ($X + 20) $Y 105 23 12 $script:Colors.Navy $true $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $Shapes $Value ($X + 122) $Y ($Width - 122) 34 12 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
}

function Assert-SlideTextFits {
  param($Slide)
  $problems = @()
  foreach ($shape in @($Slide.Shapes)) {
    try {
      if ($shape.HasTextFrame -eq $msoTrue -and $shape.TextFrame2.HasText -eq $msoTrue) {
        $availableHeight = [Math]::Max(1, $shape.Height - $shape.TextFrame2.MarginTop - $shape.TextFrame2.MarginBottom)
        $availableWidth = [Math]::Max(1, $shape.Width - $shape.TextFrame2.MarginLeft - $shape.TextFrame2.MarginRight)
        $boundHeight = $shape.TextFrame2.TextRange.BoundHeight
        $boundWidth = $shape.TextFrame2.TextRange.BoundWidth
        if ($boundHeight -gt ($availableHeight + 4) -or $boundWidth -gt ($availableWidth + 5)) {
          $problems += "slide $($Slide.SlideIndex), shape '$($shape.Name)' ($([Math]::Round($boundWidth,1))x$([Math]::Round($boundHeight,1)) in $([Math]::Round($availableWidth,1))x$([Math]::Round($availableHeight,1)))"
        }
      }
    } catch {
      # Some decorative shapes expose a text frame that PowerPoint cannot measure.
    }
  }
  return $problems
}

function New-ContactSheet {
  param([string]$SourceDirectory, [string]$OutputPath)
  Add-Type -AssemblyName System.Drawing
  $files = @(Get-ChildItem -LiteralPath $SourceDirectory -File -Filter '*.PNG' | Sort-Object Name)
  if ($files.Count -eq 0) { throw 'No rendered slides found for contact sheet.' }
  $thumbWidth = 720
  $thumbHeight = 405
  $margin = 24
  $columns = 2
  $rows = [Math]::Ceiling($files.Count / $columns)
  $canvas = New-Object System.Drawing.Bitmap (($columns * $thumbWidth) + (($columns + 1) * $margin)), (($rows * $thumbHeight) + (($rows + 1) * $margin))
  $graphics = [System.Drawing.Graphics]::FromImage($canvas)
  $graphics.Clear([System.Drawing.Color]::FromArgb(31, 43, 54))
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  for ($i = 0; $i -lt $files.Count; $i++) {
    $image = [System.Drawing.Image]::FromFile($files[$i].FullName)
    try {
      $column = $i % $columns
      $row = [Math]::Floor($i / $columns)
      $x = $margin + ($column * ($thumbWidth + $margin))
      $y = $margin + ($row * ($thumbHeight + $margin))
      $graphics.DrawImage($image, $x, $y, $thumbWidth, $thumbHeight)
    } finally {
      $image.Dispose()
    }
  }
  $canvas.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $canvas.Dispose()
}

$powerPoint = $null
$presentation = $null

try {
  $powerPoint = New-Object -ComObject PowerPoint.Application
  $presentation = $powerPoint.Presentations.Add($msoFalse)
  $presentation.PageSetup.SlideWidth = $script:SlideWidth
  $presentation.PageSetup.SlideHeight = $script:SlideHeight

  $master = $presentation.SlideMaster

  # Branded reusable layouts for the .potx file.
  $titleLayout = $master.CustomLayouts.Add($master.CustomLayouts.Count + 1)
  $titleLayout.Name = 'LibeR - Title'
  Clear-LayoutShapes $titleLayout
  Add-DarkLayoutChrome $titleLayout
  $titlePlaceholder = $titleLayout.Shapes.AddPlaceholder($ppPlaceholderTitle, 55, 142, 680, 112)
  Style-Placeholder $titlePlaceholder 34 $script:Colors.White $true $script:FontDisplay
  $subtitlePlaceholder = $titleLayout.Shapes.AddPlaceholder($ppPlaceholderSubtitle, 58, 270, 620, 72)
  Style-Placeholder $subtitlePlaceholder 18 '#D4DEE7' $false $script:FontBody

  $contentLayout = $master.CustomLayouts.Add($master.CustomLayouts.Count + 1)
  $contentLayout.Name = 'LibeR - Content'
  Clear-LayoutShapes $contentLayout
  Add-LightLayoutChrome $contentLayout
  $contentTitle = $contentLayout.Shapes.AddPlaceholder($ppPlaceholderTitle, 43, 65, 870, 42)
  Style-Placeholder $contentTitle 27 $script:Colors.Navy $true $script:FontDisplay
  $contentBody = $contentLayout.Shapes.AddPlaceholder($ppPlaceholderBody, 44, 125, 870, 355)
  Style-Placeholder $contentBody 18 $script:Colors.Text $false $script:FontBody

  $twoColumnLayout = $master.CustomLayouts.Add($master.CustomLayouts.Count + 1)
  $twoColumnLayout.Name = 'LibeR - Two columns'
  Clear-LayoutShapes $twoColumnLayout
  Add-LightLayoutChrome $twoColumnLayout
  $twoTitle = $twoColumnLayout.Shapes.AddPlaceholder($ppPlaceholderTitle, 43, 65, 870, 42)
  Style-Placeholder $twoTitle 27 $script:Colors.Navy $true $script:FontDisplay
  Add-Card $twoColumnLayout.Shapes 44 126 420 350 | Out-Null
  Add-Card $twoColumnLayout.Shapes 486 126 430 350 | Out-Null
  $leftBody = $twoColumnLayout.Shapes.AddPlaceholder($ppPlaceholderBody, 64, 145, 380, 310)
  $rightBody = $twoColumnLayout.Shapes.AddPlaceholder($ppPlaceholderBody, 506, 145, 390, 310)
  Style-Placeholder $leftBody 17 $script:Colors.Text $false $script:FontBody
  Style-Placeholder $rightBody 17 $script:Colors.Text $false $script:FontBody

  $closingLayout = $master.CustomLayouts.Add($master.CustomLayouts.Count + 1)
  $closingLayout.Name = 'LibeR - Closing'
  Clear-LayoutShapes $closingLayout
  Add-DarkLayoutChrome $closingLayout
  $closingTitle = $closingLayout.Shapes.AddPlaceholder($ppPlaceholderCenterTitle, 90, 110, 780, 80)
  Style-Placeholder $closingTitle 34 $script:Colors.White $true $script:FontDisplay
  $closingSubtitle = $closingLayout.Shapes.AddPlaceholder($ppPlaceholderSubtitle, 130, 200, 700, 72)
  Style-Placeholder $closingSubtitle 18 '#D4DEE7' $false $script:FontBody

  # Save the reusable branded template before any content slides are added.
  $presentation.SaveCopyAs($templatePath, $ppSaveAsOpenXMLTemplate)

  # Slide 1: title.
  $slide = $presentation.Slides.AddSlide(1, $titleLayout)
  Add-Pill $slide.Shapes 'OPEN-SOURCE POPULATION PK/PD MODELLING' 56 112 330 27 $script:Colors.Blue $script:Colors.White 11 | Out-Null
  Add-Text $slide.Shapes 'LibeR' 55 160 420 58 41 $script:Colors.White $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes "From model code to a complete`npharmacometrics workflow" 55 218 560 104 30 '#DCE6EE' $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  Add-Text $slide.Shapes 'Automatic differentiation • PK/PD algorithms • GUI • scalable execution' 58 337 650 38 16 '#AFC1D0' $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  Add-Text $slide.Shapes 'Sven C. van Dijkman  |  University presentation  |  16 July 2026' 58 462 630 24 12 '#AFC1D0' $false $script:FontBody $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  # A stylised editable PK concentration-time curve.
  $curvePoints = @(
    @(650, 350), @(682, 260), @(716, 220), @(754, 234),
    @(796, 280), @(842, 327), @(895, 365)
  )
  for ($i = 0; $i -lt ($curvePoints.Count - 1); $i++) {
    $segment = $slide.Shapes.AddLine($curvePoints[$i][0], $curvePoints[$i][1], $curvePoints[$i + 1][0], $curvePoints[$i + 1][1])
    Set-Line $segment '#76A6CB' 3 0.05
  }
  foreach ($point in $curvePoints) { Add-Circle $slide.Shapes ($point[0] - 4) ($point[1] - 4) 8 $script:Colors.Green | Out-Null }
  Add-Text $slide.Shapes 'concentration' 642 378 95 18 10 '#88A0B2' $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes 'time' 860 378 42 18 10 '#88A0B2' $false $script:FontBody $msoAlignRight $msoAnchorTop 0 $false | Out-Null

  # Slide 2: AD and algorithms.
  $slide = $presentation.Slides.AddSlide(2, $contentLayout)
  Add-SlideTitle $slide 'From model code to reliable derivatives' 'LibeRtAD turns an R or C++ model into a native C++ calculation graph.'
  $cardXs = @(48, 354, 660)
  $cardColors = @($script:Colors.PaleBlue, $script:Colors.PaleTeal, $script:Colors.PalePurple)
  $accents = @($script:Colors.Blue, $script:Colors.Teal, $script:Colors.Purple)
  $labels = @('1  MODEL', '2  DIFFERENTIATE', '3  ESTIMATE')
  $headings = @('Write what you mean', 'Get exact sensitivities', 'Use pharmacometric algorithms')
  $details = @(
    'R code, C++ code, or an imported NONMEM control stream',
    'CppAD records the calculation and supplies gradients and curvature',
    'FOCEI, Laplace, ITS, IMP, SAEM, Bayesian methods and more'
  )
  $symbols = @('M', 'AD', 'PK')
  for ($i = 0; $i -lt 3; $i++) {
    Add-Card $slide.Shapes $cardXs[$i] 150 250 154 $cardColors[$i] $script:Colors.Line | Out-Null
    Add-Circle $slide.Shapes ($cardXs[$i] + 18) 168 40 $accents[$i] | Out-Null
    $symbolShape = Add-Text $slide.Shapes $symbols[$i] ($cardXs[$i] + 18) 168 40 40 14 $script:Colors.White $true $(if ($i -eq 0) { $script:FontMono } else { $script:FontDisplay }) $msoAlignCenter $msoAnchorMiddle 0 $false
    $symbolShape.TextFrame2.AutoSize = 0
    $symbolShape.Left = $cardXs[$i] + 18
    $symbolShape.Top = 168
    $symbolShape.Width = 40
    $symbolShape.Height = 40
    Add-Text $slide.Shapes $labels[$i] ($cardXs[$i] + 70) 170 158 20 10 $accents[$i] $true $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
    Add-Text $slide.Shapes $headings[$i] ($cardXs[$i] + 18) 211 214 43 16 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
    Add-Text $slide.Shapes $details[$i] ($cardXs[$i] + 18) 261 214 34 11.5 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  }
  Add-Connector $slide.Shapes 305 227 344 227 $script:Colors.Blue 2.2 $true | Out-Null
  Add-Connector $slide.Shapes 611 227 650 227 $script:Colors.Teal 2.2 $true | Out-Null
  Add-Rectangle $slide.Shapes 48 329 862 68 $script:Colors.Navy '' 8 | Out-Null
  Add-Text $slide.Shapes 'What this unlocks' 68 346 135 24 13 $script:Colors.White $true $script:FontDisplay $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  Add-Pill $slide.Shapes 'Stable optimisation' 218 346 170 31 '#35536D' $script:Colors.White 12 | Out-Null
  Add-Pill $slide.Shapes 'Fast uncertainty' 404 346 155 31 '#35665B' $script:Colors.White 12 | Out-Null
  Add-Pill $slide.Shapes 'Transparent diagnostics' 575 346 198 31 '#3E647C' $script:Colors.White 12 | Out-Null
  Add-Pill $slide.Shapes 'Reusable engine' 789 346 101 31 '#4D4668' $script:Colors.White 10.5 | Out-Null
  Add-Rectangle $slide.Shapes 48 423 862 57 $script:Colors.PaleOrange $script:Colors.Orange 8 0 0.8 | Out-Null
  Add-Text $slide.Shapes 'Pharmacometrics joke:' 68 439 155 22 12 $script:Colors.Orange $true $script:FontBody $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  Add-Text $slide.Shapes 'AD does not remove uncertainty — it just stops the optimiser adding its own.' 220 439 660 22 13 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  Add-SlideNumber $slide 2

  # Slide 3: ecosystem architecture.
  $slide = $presentation.Slides.AddSlide(3, $contentLayout)
  Add-SlideTitle $slide 'One ecosystem, three focused packages' 'A single modelling workflow, with each package doing one job well.'

  Add-Card $slide.Shapes 48 155 175 222 $script:Colors.Surface $script:Colors.Line | Out-Null
  Add-Pill $slide.Shapes 'YOU START HERE' 66 174 139 25 $script:Colors.PaleBlue $script:Colors.Blue 10 | Out-Null
  Add-Text $slide.Shapes 'Model + data' 68 215 135 28 19 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes "R model`nC++ model`nNONMEM control stream`nClinical / preclinical data" 68 253 130 96 12.5 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null

  Add-Card $slide.Shapes 286 145 360 134 $script:Colors.PaleBlue $script:Colors.Blue | Out-Null
  Add-Pill $slide.Shapes 'WORKBENCH' 306 164 105 24 $script:Colors.Blue $script:Colors.White 10 | Out-Null
  Add-Text $slide.Shapes 'LibeRation' 306 200 210 31 23 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes 'Projects • models • estimation • simulation • diagnostics • reports' 306 235 310 28 12.5 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null

  Add-Card $slide.Shapes 286 317 360 119 $script:Colors.PaleTeal $script:Colors.Teal | Out-Null
  Add-Pill $slide.Shapes 'NUMERICAL CORE' 306 335 125 24 $script:Colors.Teal $script:Colors.White 10 | Out-Null
  Add-Text $slide.Shapes 'LibeRtAD' 306 371 170 28 21 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes 'C++ automatic differentiation • ADVAN • ODE • steady state' 306 404 315 22 12 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null

  Add-Card $slide.Shapes 710 145 202 291 $script:Colors.PalePurple $script:Colors.Purple | Out-Null
  Add-Pill $slide.Shapes 'EXECUTION' 731 164 96 24 $script:Colors.Purple $script:Colors.White 10 | Out-Null
  Add-Text $slide.Shapes 'LibeRties' 731 201 150 29 22 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes "Local queue`nRemote server`nUser isolation`nDurable jobs`nLogs + results" 731 250 145 125 13 $script:Colors.Text $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  Add-Pill $slide.Shapes 'Windows • Linux • macOS' 731 390 158 27 '#DCD7E7' $script:Colors.Purple 10.5 | Out-Null

  Add-Connector $slide.Shapes 224 246 276 246 $script:Colors.Blue 2.5 $true | Out-Null
  Add-Connector $slide.Shapes 466 285 466 307 $script:Colors.Teal 2.5 $true | Out-Null
  Add-Connector $slide.Shapes 656 218 700 218 $script:Colors.Purple 2.5 $true | Out-Null
  Add-Connector $slide.Shapes 700 371 656 371 $script:Colors.Purple 1.7 $true $true | Out-Null
  Add-Text $slide.Shapes 'results' 658 380 41 16 9 $script:Colors.Muted $false $script:FontBody $msoAlignCenter $msoAnchorTop 0 $false | Out-Null
  Add-Pill $slide.Shapes 'One model specification • one job contract • one traceable workflow' 244 462 510 27 $script:Colors.Navy $script:Colors.White 11.5 | Out-Null
  Add-SlideNumber $slide 3

  # Slide 4: capabilities and benchmark.
  $slide = $presentation.Slides.AddSlide(4, $contentLayout)
  Add-SlideTitle $slide 'Broad capability, promising performance' 'The current build covers the workflow from model specification to diagnostics.'
  Add-Card $slide.Shapes 44 137 400 346 $script:Colors.Surface $script:Colors.Line | Out-Null
  Add-Text $slide.Shapes 'Current LibeRation capabilities' 64 156 350 27 17 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-LabelValueRow $slide.Shapes 'AUTHOR' 'R, C++, or NONMEM control streams' 66 199 350 $script:Colors.Blue
  Add-LabelValueRow $slide.Shapes 'SOLVE' 'ADVAN1–4/11/12, ODEs, matrix exponential, steady state' 66 245 350 $script:Colors.Teal
  Add-LabelValueRow $slide.Shapes 'ESTIMATE' 'FO, FOCE/I, Laplace, ITS, IMP, SAEM and Bayes' 66 298 350 $script:Colors.Purple
  Add-LabelValueRow $slide.Shapes 'DIAGNOSE' 'GOF, CWRES, VPC, NPDE, NPC and categorical/TTE VPCs' 66 351 350 $script:Colors.Orange
  Add-LabelValueRow $slide.Shapes 'QUANTIFY' 'Covariance, bootstrap, profile likelihood and priors' 66 404 350 $script:Colors.Green
  Add-Text $slide.Shapes 'Plus parallel simulation/estimation, SCM, versioned runs and reporting.' 66 451 350 24 10.5 $script:Colors.Muted $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null

  Add-Card $slide.Shapes 466 137 450 346 $script:Colors.Surface $script:Colors.Line | Out-Null
  Add-Text $slide.Shapes 'End-to-end speedup vs NONMEM' 486 156 320 27 17 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Pill $slide.Shapes 'higher is faster' 804 155 91 23 $script:Colors.PaleGreen $script:Colors.Green 9.5 | Out-Null
  Add-Text $slide.Shapes 'NONMEM time ÷ LibeRation time' 486 183 260 18 10 $script:Colors.Muted $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  $benchmarks = @(
    @('FO', 4.81, $script:Colors.Blue),
    @('FOCE', 2.78, $script:Colors.Blue),
    @('FOCEI', 2.73, $script:Colors.Blue),
    @('Laplace', 3.34, $script:Colors.Teal),
    @('ITS', 12.68, $script:Colors.Purple),
    @('IMP', 6.44, $script:Colors.Purple),
    @('SAEM', 1.26, $script:Colors.Orange),
    @('Simulation', 11.54, $script:Colors.Green)
  )
  $barX = 560.0
  $barMaxWidth = 280.0
  $maxValue = 13.0
  $rowY = 213.0
  for ($i = 0; $i -lt $benchmarks.Count; $i++) {
    $method = [string]$benchmarks[$i][0]
    $value = [double]$benchmarks[$i][1]
    $color = [string]$benchmarks[$i][2]
    $y = $rowY + ($i * 27.5)
    Add-Text $slide.Shapes $method 487 $y 67 18 10.5 $script:Colors.Text $true $script:FontBody $msoAlignRight $msoAnchorMiddle 0 $false | Out-Null
    Add-Rectangle $slide.Shapes $barX ($y + 3) $barMaxWidth 13 '#E6EBEF' '' 4 | Out-Null
    $width = [Math]::Max(8, ($value / $maxValue) * $barMaxWidth)
    Add-Rectangle $slide.Shapes $barX ($y + 3) $width 13 $color '' 4 | Out-Null
    Add-Text $slide.Shapes ('{0:0.0}×' -f $value) ($barX + $width + 6) ($y - 1) 48 20 10.5 $color $true $script:FontBody $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  }
  $oneX = $barX + (($barMaxWidth / $maxValue) * 1.0)
  $reference = $slide.Shapes.AddLine($oneX, 207, $oneX, 438)
  Set-Line $reference $script:Colors.Green 1.2 0.15
  $reference.Line.DashStyle = 4
  Add-Text $slide.Shapes '1×' ($oneX - 10) 438 28 15 8.5 $script:Colors.Green $true $script:FontBody $msoAlignCenter $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes "100 subjects • 800 records • 1 core • end-to-end wall time.`nDevelopment benchmark, 14 Jul 2026: LibeRation = 1 fresh run; NONMEM = median of 3 prior runs. Validate independently." 486 449 408 31 9 $script:Colors.Muted $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  Add-SlideNumber $slide 4

  # Slide 5: LibeRties and live demo hand-off.
  $slide = $presentation.Slides.AddSlide(5, $contentLayout)
  Add-SlideTitle $slide 'LibeRties: run locally, scale remotely' 'The same job contract can move from a laptop queue to a shared server.'
  $steps = @(
    @('1', 'SUBMIT', 'Model, data and run settings', $script:Colors.Blue, $script:Colors.PaleBlue),
    @('2', 'QUEUE', 'Persistent state and scheduling', $script:Colors.Teal, $script:Colors.PaleTeal),
    @('3', 'WORK', 'Isolated process with limits', $script:Colors.Purple, $script:Colors.PalePurple),
    @('4', 'RETURN', 'Logs, status and results', $script:Colors.Green, $script:Colors.PaleGreen)
  )
  $stepX = @(48, 270, 492, 714)
  for ($i = 0; $i -lt $steps.Count; $i++) {
    Add-Card $slide.Shapes $stepX[$i] 166 198 142 $steps[$i][4] $steps[$i][3] | Out-Null
    Add-Circle $slide.Shapes ($stepX[$i] + 18) 184 34 $steps[$i][3] | Out-Null
    Add-Text $slide.Shapes $steps[$i][0] ($stepX[$i] + 18) 184 34 34 14 $script:Colors.White $true $script:FontDisplay $msoAlignCenter $msoAnchorMiddle 0 $false | Out-Null
    Add-Text $slide.Shapes $steps[$i][1] ($stepX[$i] + 64) 188 110 20 10 $steps[$i][3] $true $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
    Add-Text $slide.Shapes $steps[$i][2] ($stepX[$i] + 18) 235 162 48 14 $script:Colors.Navy $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
    if ($i -lt ($steps.Count - 1)) {
      Add-Connector $slide.Shapes ($stepX[$i] + 200) 237 ($stepX[$i + 1] - 8) 237 $script:Colors.Blue 2 $true | Out-Null
    }
  }
  Add-Pill $slide.Shapes 'LOCAL OR REMOTE' 80 335 150 28 $script:Colors.Navy $script:Colors.White 11 | Out-Null
  Add-Pill $slide.Shapes 'MULTI-USER ISOLATION' 255 335 170 28 $script:Colors.PalePurple $script:Colors.Purple 11 | Out-Null
  Add-Pill $slide.Shapes 'QUOTAS + CANCELLATION' 450 335 180 28 $script:Colors.PaleOrange $script:Colors.Orange 11 | Out-Null
  Add-Pill $slide.Shapes 'RESTART RECOVERY' 655 335 150 28 $script:Colors.PaleGreen $script:Colors.Green 11 | Out-Null
  Add-Text $slide.Shapes 'Designed for Windows testing today and Linux server deployment tomorrow.' 80 379 725 24 12.5 $script:Colors.Muted $false $script:FontBody $msoAlignCenter $msoAnchorMiddle 0 $false | Out-Null
  Add-Rectangle $slide.Shapes 48 426 864 61 $script:Colors.Navy '' 8 | Out-Null
  Add-Pill $slide.Shapes 'NEXT' 69 443 65 27 $script:Colors.Green $script:Colors.White 11 | Out-Null
  Add-Text $slide.Shapes 'Live demo: create → estimate → diagnose → queue' 152 440 700 31 17 $script:Colors.White $true $script:FontDisplay $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  Add-SlideNumber $slide 5

  # Slide 6: conclusions.
  $slide = $presentation.Slides.AddSlide(6, $closingLayout)
  Add-Pill $slide.Shapes 'AFTER THE DEMO' 56 106 122 26 $script:Colors.Teal $script:Colors.White 10 | Out-Null
  Add-Text $slide.Shapes 'What to remember' 55 147 620 49 34 $script:Colors.White $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
  Add-Text $slide.Shapes 'LibeR connects approachable model building with a modern numerical core.' 58 200 700 32 16 '#B8C8D5' $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  $conclusionX = @(58, 354, 650)
  $conclusionNumbers = @('01', '02', '03')
  $conclusionTitles = @('Approachable', 'Powerful', 'Scalable')
  $conclusionTexts = @(
    'GUI workflow with R, C++ and NONMEM interoperability',
    'Automatic differentiation, specialist PK/PD solvers and diagnostics',
    'Local queues and remote execution with durable job state'
  )
  $conclusionColors = @($script:Colors.Blue, $script:Colors.Teal, $script:Colors.Green)
  for ($i = 0; $i -lt 3; $i++) {
    Add-Rectangle $slide.Shapes $conclusionX[$i] 264 250 126 $script:Colors.DarkSurface '#344452' 8 | Out-Null
    Add-Text $slide.Shapes $conclusionNumbers[$i] ($conclusionX[$i] + 18) 281 48 26 12 $conclusionColors[$i] $true $script:FontBody $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
    Add-Text $slide.Shapes $conclusionTitles[$i] ($conclusionX[$i] + 18) 311 205 27 19 $script:Colors.White $true $script:FontDisplay $msoAlignLeft $msoAnchorTop 0 $false | Out-Null
    Add-Text $slide.Shapes $conclusionTexts[$i] ($conclusionX[$i] + 18) 344 210 38 11.5 '#B8C8D5' $false $script:FontBody $msoAlignLeft $msoAnchorTop 0 $true | Out-Null
  }
  Add-Rectangle $slide.Shapes 58 420 842 58 '#1F3243' '#476176' 8 | Out-Null
  Add-Text $slide.Shapes 'Take-home:' 78 438 105 23 13 $script:Colors.Green $true $script:FontBody $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  Add-Text $slide.Shapes 'transparent PK/PD workflows without giving up performance.' 180 436 600 26 17 $script:Colors.White $true $script:FontDisplay $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null
  Add-Text $slide.Shapes 'Questions & discussion' 700 490 200 22 13 '#B8C8D5' $true $script:FontBody $msoAlignRight $msoAnchorMiddle 0 $false | Out-Null
  Add-Text $slide.Shapes 'github.com/svdijkman  •  MIT licensed' 58 490 310 22 10 '#88A0B2' $false $script:FontBody $msoAlignLeft $msoAnchorMiddle 0 $false | Out-Null

  $fitProblems = @()
  foreach ($candidateSlide in @($presentation.Slides)) {
    $fitProblems += @(Assert-SlideTextFits $candidateSlide)
  }
  if ($fitProblems.Count -gt 0) {
    Write-Warning ('Potential text fitting issues:' + [Environment]::NewLine + ($fitProblems -join [Environment]::NewLine))
  }

  $presentation.SaveAs($deckPath, $ppSaveAsOpenXMLPresentation)
} finally {
  if ($presentation -ne $null) {
    try { $presentation.Close() } catch { }
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($presentation)
  }
  if ($powerPoint -ne $null) {
    try { $powerPoint.Quit() } catch { }
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint)
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}

$validationPowerPoint = $null
$validationPresentation = $null
try {
  $validationPowerPoint = New-Object -ComObject PowerPoint.Application
  $validationPowerPoint.Visible = $msoTrue
  $validationPresentation = $validationPowerPoint.Presentations.Open($deckPath, $msoTrue, $msoFalse, $msoTrue)
  if ($validationPresentation.Slides.Count -ne 6) {
    throw "Expected six slides after reopening the deck; found $($validationPresentation.Slides.Count)."
  }
  $validationPresentation.Windows.Item(1).View.GotoSlide(1)
  Start-Sleep -Milliseconds 1500
  $validationPresentation.Export($RenderDirectory, 'PNG', 1600, 900)
  Start-Sleep -Milliseconds 3000
} finally {
  if ($validationPresentation -ne $null) {
    try { $validationPresentation.Close() } catch { }
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($validationPresentation)
  }
  if ($validationPowerPoint -ne $null) {
    try { $validationPowerPoint.Quit() } catch { }
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($validationPowerPoint)
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}

$contactSheet = Join-Path $RenderDirectory 'contact-sheet.png'
New-ContactSheet $RenderDirectory $contactSheet

[pscustomobject]@{
  Template = $templatePath
  Presentation = $deckPath
  TemplateBytes = (Get-Item -LiteralPath $templatePath).Length
  PresentationBytes = (Get-Item -LiteralPath $deckPath).Length
  RenderDirectory = $RenderDirectory
  ContactSheet = $contactSheet
}
