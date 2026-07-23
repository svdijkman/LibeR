param(
  [string]$Source = "tools/assets/liber-dove-source.svg",
  [string]$Canonical = "tools/assets/liber-dove-source.svg",
  [string]$Client = "LibeRation/inst/assets/favicon.svg",
  [string]$Server = "LibeRties/inst/admin-assets/favicon.svg",
  [string]$LibeRator = "LibeRator/inst/assets/favicon.svg",
  [string]$LibeRtAD = "LibeRtAD/inst/assets/favicon.svg",
  [string]$LibeRality = "LibeRality/inst/assets/favicon.svg",
  [string[]]$Library = @(
    "LibeRary/inst/shiny/www/favicon.svg",
    "LibeRary/inst/shiny-ingest/www/favicon.svg"
  ),
  [int]$Size = 512
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path ".").Path
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class LiberDoveProcessor {
  public static void RemoveConnectedWhitespace(Bitmap bitmap) {
    int width = bitmap.Width, height = bitmap.Height;
    var rectangle = new Rectangle(0, 0, width, height);
    var data = bitmap.LockBits(rectangle, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    try {
      var bytes = new byte[Math.Abs(data.Stride) * height];
      Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
      var visited = new bool[width * height];
      var queue = new Queue<int>();
      Action<int, int> add = null;
      add = (x, y) => {
        if (x < 0 || y < 0 || x >= width || y >= height) return;
        int index = y * width + x;
        if (visited[index]) return;
        visited[index] = true;
        int offset = y * data.Stride + x * 4;
        int blue = bytes[offset], green = bytes[offset + 1], red = bytes[offset + 2];
        int maximum = Math.Max(red, Math.Max(green, blue));
        int minimum = Math.Min(red, Math.Min(green, blue));
        if (maximum - minimum <= 30 && red >= 170 && green >= 170 && blue >= 170) {
          queue.Enqueue(index);
        }
      };
      for (int x = 0; x < width; x++) { add(x, 0); add(x, height - 1); }
      for (int y = 1; y < height - 1; y++) { add(0, y); add(width - 1, y); }
      while (queue.Count > 0) {
        int index = queue.Dequeue(), x = index % width, y = index / width;
        bytes[y * data.Stride + x * 4 + 3] = 0;
        add(x - 1, y); add(x + 1, y); add(x, y - 1); add(x, y + 1);
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally {
      bitmap.UnlockBits(data);
    }
  }

  public static void RecolourBlue(Bitmap bitmap, double hue, double saturationScale,
                                  double saturationOffset, double valueScale,
                                  double valueOffset) {
    var rectangle = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
    var data = bitmap.LockBits(rectangle, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    try {
      var bytes = new byte[Math.Abs(data.Stride) * bitmap.Height];
      Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
      for (int y = 0; y < bitmap.Height; y++) for (int x = 0; x < bitmap.Width; x++) {
        int offset = y * data.Stride + x * 4;
        int blue = bytes[offset], green = bytes[offset + 1], red = bytes[offset + 2];
        if (bytes[offset + 3] == 0 || blue <= red || blue < green) continue;
        double maximum = Math.Max(red, Math.Max(green, blue)) / 255.0;
        double minimum = Math.Min(red, Math.Min(green, blue)) / 255.0;
        double chroma = maximum - minimum;
        if (chroma < 0.04 || maximum <= 0.0) continue;

        double saturation = Math.Min(1.0, (chroma / maximum) * saturationScale + saturationOffset);
        double value = Math.Min(1.0, maximum * valueScale + valueOffset);
        double targetChroma = value * saturation;
        double sector = hue / 60.0;
        double targetX = targetChroma * (1.0 - Math.Abs(sector % 2.0 - 1.0));
        double targetOffset = value - targetChroma;
        double r = 0, g = 0, b = 0;
        if (sector < 1) { r = targetChroma; g = targetX; }
        else if (sector < 2) { r = targetX; g = targetChroma; }
        else if (sector < 3) { g = targetChroma; b = targetX; }
        else if (sector < 4) { g = targetX; b = targetChroma; }
        else if (sector < 5) { r = targetX; b = targetChroma; }
        else { r = targetChroma; b = targetX; }
        bytes[offset + 2] = (byte)Math.Round(255 * (r + targetOffset));
        bytes[offset + 1] = (byte)Math.Round(255 * (g + targetOffset));
        bytes[offset] = (byte)Math.Round(255 * (b + targetOffset));
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally {
      bitmap.UnlockBits(data);
    }
  }

  public static Bitmap Resize(Bitmap source, int size) {
    var result = new Bitmap(size, size, PixelFormat.Format32bppArgb);
    result.SetResolution(96, 96);
    using (var graphics = Graphics.FromImage(result)) {
      graphics.Clear(Color.Transparent);
      graphics.CompositingMode = CompositingMode.SourceCopy;
      graphics.CompositingQuality = CompositingQuality.HighQuality;
      graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
      graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
      graphics.SmoothingMode = SmoothingMode.HighQuality;
      graphics.DrawImage(source, new Rectangle(0, 0, size, size),
                         0, 0, source.Width, source.Height, GraphicsUnit.Pixel);
    }
    return result;
  }
}
'@

function Resolve-RepositoryTarget([string]$Path) {
  $target = [IO.Path]::GetFullPath((Join-Path $root $Path))
  if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
      [StringComparison]::OrdinalIgnoreCase)) {
    throw "Favicon target must remain inside the repository: $Path"
  }
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
  $target
}

function Read-EmbeddedBitmap([string]$Path) {
  $sourcePath = (Resolve-Path -LiteralPath $Path).Path
  $text = [IO.File]::ReadAllText($sourcePath)
  $match = [regex]::Match($text, '(?:href|xlink:href)="data:image/png;base64,([^"]+)')
  if (-not $match.Success) { throw "No embedded PNG found in $sourcePath" }
  $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
  $stream = [IO.MemoryStream]::new($bytes)
  try {
    $sourceBitmap = [Drawing.Bitmap]::new($stream)
    try {
      $bitmap = [Drawing.Bitmap]::new(
        $sourceBitmap.Width, $sourceBitmap.Height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
      )
      $graphics = [Drawing.Graphics]::FromImage($bitmap)
      try { $graphics.DrawImageUnscaled($sourceBitmap, 0, 0) } finally { $graphics.Dispose() }
      $bitmap
    } finally {
      $sourceBitmap.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Write-EmbeddedSvg(
  [Drawing.Bitmap]$Bitmap, [string]$Path, [string]$Id, [string]$Label
) {
  $target = Resolve-RepositoryTarget $Path
  $stream = [IO.MemoryStream]::new()
  try {
    $Bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
    $base64 = [Convert]::ToBase64String($stream.ToArray())
  } finally {
    $stream.Dispose()
  }
  $svg = '<svg xmlns="http://www.w3.org/2000/svg" id="' + $Id +
    '" width="' + $Bitmap.Width + '" height="' + $Bitmap.Height +
    '" viewBox="0 0 ' + $Bitmap.Width + ' ' + $Bitmap.Height +
    '" role="img" aria-label="' + $Label + '"><image width="' +
    $Bitmap.Width + '" height="' + $Bitmap.Height +
    '" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,' +
    $base64 + '"/></svg>'
  [IO.File]::WriteAllText($target, $svg, [Text.UTF8Encoding]::new($false))
}

function Write-RecolouredVariant(
  [Drawing.Bitmap]$SourceBitmap, [string]$Path, [string]$Id, [string]$Label,
  [double]$Hue, [double]$SaturationScale, [double]$SaturationOffset,
  [double]$ValueScale, [double]$ValueOffset
) {
  $variant = [Drawing.Bitmap]$SourceBitmap.Clone()
  try {
    [LiberDoveProcessor]::RecolourBlue(
      $variant, $Hue, $SaturationScale, $SaturationOffset, $ValueScale, $ValueOffset
    )
    Write-EmbeddedSvg $variant $Path $Id $Label
  } finally {
    $variant.Dispose()
  }
}

if ($Size -lt 128 -or $Size -gt 1024) {
  throw "Size must be between 128 and 1024 pixels."
}

$sourceBitmap = Read-EmbeddedBitmap $Source
try {
  [LiberDoveProcessor]::RemoveConnectedWhitespace($sourceBitmap)
  $master = [LiberDoveProcessor]::Resize($sourceBitmap, $Size)
  try {
    Write-EmbeddedSvg $master $Canonical "liber-dove-source" "LibeR dove"
    Write-EmbeddedSvg $master $Client "liberation-dove" "LibeRation"
    Write-RecolouredVariant $master $Server "liberties-dove" "LibeRties" 354 0.76 0.10 0.97 0.02
    Write-RecolouredVariant $master $LibeRator "liberator-dove" "LibeRator" 181 0.68 0.09 0.97 0.02
    Write-RecolouredVariant $master $LibeRtAD "libertad-dove" "LibeRtAD" 273 0.72 0.10 0.98 0.02
    Write-RecolouredVariant $master $LibeRality "liberality-dove" "LibeRality" 36 0.74 0.12 0.96 0.02
    foreach ($path in $Library) {
      Write-RecolouredVariant $master $path "liberary-dove" "LibeRary" 148 0.78 0.08 0.98 0.01
    }
  } finally {
    $master.Dispose()
  }
} finally {
  $sourceBitmap.Dispose()
}
