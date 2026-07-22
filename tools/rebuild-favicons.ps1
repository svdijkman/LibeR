param(
  [string]$Client = "LibeRation/inst/assets/favicon.svg",
  [string]$Server = "LibeRties/inst/admin-assets/favicon.svg",
  [string]$LibeRator = "LibeRator/inst/assets/favicon.svg",
  [string]$LibeRtAD = "LibeRtAD/inst/assets/favicon.svg",
  [string]$LibeRality = "LibeRality/inst/assets/favicon.svg",
  [string[]]$Library = @(
    "LibeRary/inst/shiny/www/favicon.svg",
    "LibeRary/inst/shiny-ingest/www/favicon.svg"
  ),
  [switch]$LibraryOnly,
  [switch]$LibeRatorOnly,
  [switch]$LibeRtADOnly,
  [switch]$LibeRalityOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class LiberFaviconProcessor {
  public static void RemoveConnectedWhitespace(Bitmap bitmap) {
    int width = bitmap.Width, height = bitmap.Height;
    var rectangle = new Rectangle(0, 0, width, height);
    var data = bitmap.LockBits(rectangle, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    try {
      var bytes = new byte[Math.Abs(data.Stride) * height];
      Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
      var visited = new bool[width * height];
      var queue = new Queue<int>();
      Action<int,int> add = null;
      add = (x, y) => {
        if (x < 0 || y < 0 || x >= width || y >= height) return;
        int index = y * width + x;
        if (visited[index]) return;
        visited[index] = true;
        int offset = y * data.Stride + x * 4;
        int blue = bytes[offset], green = bytes[offset + 1], red = bytes[offset + 2];
        int maximum = Math.Max(red, Math.Max(green, blue));
        int minimum = Math.Min(red, Math.Min(green, blue));
        if (maximum - minimum <= 28 && red >= 175 && green >= 175 && blue >= 175) {
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
    } finally { bitmap.UnlockBits(data); }
  }

  public static void BlueToRed(Bitmap bitmap) {
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
        if (chroma < 0.04) continue;
        double secondary = chroma * 0.10, channelOffset = maximum - chroma;
        bytes[offset + 2] = (byte)Math.Round(255 * (chroma + channelOffset));
        bytes[offset + 1] = (byte)Math.Round(255 * channelOffset);
        bytes[offset] = (byte)Math.Round(255 * (secondary + channelOffset));
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally { bitmap.UnlockBits(data); }
  }

  public static void BlueToGreen(Bitmap bitmap) {
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

        // Keep the original luminance variation, soften saturation, and move
        // blue hues to a calm leaf/forest green (approximately 148 degrees).
        double saturation = chroma / maximum;
        double targetSaturation = Math.Min(1.0, saturation * 0.78 + 0.08);
        double targetValue = Math.Min(1.0, maximum * 0.98 + 0.01);
        double targetChroma = targetValue * targetSaturation;
        double targetX = targetChroma * (1.0 - Math.Abs((148.0 / 60.0) % 2.0 - 1.0));
        double targetOffset = targetValue - targetChroma;
        bytes[offset + 2] = (byte)Math.Round(255 * targetOffset);
        bytes[offset + 1] = (byte)Math.Round(255 * (targetChroma + targetOffset));
        bytes[offset] = (byte)Math.Round(255 * (targetX + targetOffset));
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally { bitmap.UnlockBits(data); }
  }

  public static void BlueToPurple(Bitmap bitmap) {
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

        // Preserve the dove's shading while moving the original blue to a
        // gentle plum-violet that remains legible in both workbench themes.
        double saturation = chroma / maximum;
        double targetSaturation = Math.Min(1.0, saturation * 0.72 + 0.10);
        double targetValue = Math.Min(1.0, maximum * 0.98 + 0.02);
        double targetChroma = targetValue * targetSaturation;
        double targetX = targetChroma * (1.0 - Math.Abs((273.0 / 60.0) % 2.0 - 1.0));
        double targetOffset = targetValue - targetChroma;
        bytes[offset + 2] = (byte)Math.Round(255 * (targetX + targetOffset));
        bytes[offset + 1] = (byte)Math.Round(255 * targetOffset);
        bytes[offset] = (byte)Math.Round(255 * (targetChroma + targetOffset));
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally { bitmap.UnlockBits(data); }
  }

  public static void BlueToTeal(Bitmap bitmap) {
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

        // Clinical teal (approximately 181 degrees), with restrained
        // saturation and the source dove's original luminance variation.
        double saturation = chroma / maximum;
        double targetSaturation = Math.Min(1.0, saturation * 0.68 + 0.09);
        double targetValue = Math.Min(1.0, maximum * 0.97 + 0.02);
        double targetChroma = targetValue * targetSaturation;
        double targetX = targetChroma * (1.0 - Math.Abs((181.0 / 60.0) % 2.0 - 1.0));
        double targetOffset = targetValue - targetChroma;
        bytes[offset + 2] = (byte)Math.Round(255 * targetOffset);
        bytes[offset + 1] = (byte)Math.Round(255 * (targetChroma + targetOffset));
        bytes[offset] = (byte)Math.Round(255 * (targetX + targetOffset));
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally { bitmap.UnlockBits(data); }
  }

  public static void BlueToAmber(Bitmap bitmap) {
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

        // Warm design amber (approximately 36 degrees), preserving the
        // original dove's highlights and shading for both workbench themes.
        double saturation = chroma / maximum;
        double targetSaturation = Math.Min(1.0, saturation * 0.74 + 0.12);
        double targetValue = Math.Min(1.0, maximum * 0.96 + 0.02);
        double targetChroma = targetValue * targetSaturation;
        double targetX = targetChroma * (1.0 - Math.Abs((36.0 / 60.0) % 2.0 - 1.0));
        double targetOffset = targetValue - targetChroma;
        bytes[offset + 2] = (byte)Math.Round(255 * (targetChroma + targetOffset));
        bytes[offset + 1] = (byte)Math.Round(255 * (targetX + targetOffset));
        bytes[offset] = (byte)Math.Round(255 * targetOffset);
      }
      Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
    } finally { bitmap.UnlockBits(data); }
  }
}
'@

function Read-EmbeddedBitmap([string]$Path) {
  $text = [IO.File]::ReadAllText((Resolve-Path $Path))
  $match = [regex]::Match($text, 'href="data:image/png;base64,([^"]+)')
  if (-not $match.Success) { throw "No embedded PNG found in $Path" }
  $bytes = [Convert]::FromBase64String($match.Groups[1].Value)
  $stream = [IO.MemoryStream]::new($bytes)
  try {
    $source = [Drawing.Bitmap]::new($stream)
    try {
      $bitmap = [Drawing.Bitmap]::new(
        $source.Width, $source.Height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
      )
      $graphics = [Drawing.Graphics]::FromImage($bitmap)
      try { $graphics.DrawImageUnscaled($source, 0, 0) } finally { $graphics.Dispose() }
      return $bitmap
    } finally { $source.Dispose() }
  } finally { $stream.Dispose() }
}

function Remove-ConnectedWhitespace([Drawing.Bitmap]$Bitmap) {
  [LiberFaviconProcessor]::RemoveConnectedWhitespace($Bitmap)
}

function Convert-BlueToRed([Drawing.Bitmap]$Bitmap) {
  [LiberFaviconProcessor]::BlueToRed($Bitmap)
}

function Convert-BlueToGreen([Drawing.Bitmap]$Bitmap) {
  [LiberFaviconProcessor]::BlueToGreen($Bitmap)
}

function Convert-BlueToPurple([Drawing.Bitmap]$Bitmap) {
  [LiberFaviconProcessor]::BlueToPurple($Bitmap)
}

function Convert-BlueToTeal([Drawing.Bitmap]$Bitmap) {
  [LiberFaviconProcessor]::BlueToTeal($Bitmap)
}

function Convert-BlueToAmber([Drawing.Bitmap]$Bitmap) {
  [LiberFaviconProcessor]::BlueToAmber($Bitmap)
}

function Write-EmbeddedSvg(
  [Drawing.Bitmap]$Bitmap, [string]$Path, [string]$Id, [string]$Label
) {
  $stream = [IO.MemoryStream]::new()
  try {
    $Bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png)
    $base64 = [Convert]::ToBase64String($stream.ToArray())
  } finally { $stream.Dispose() }
  $svg = '<svg xmlns="http://www.w3.org/2000/svg" id="' + $Id +
    '" width="1000" height="1000" viewBox="0 0 ' + $Bitmap.Width + ' ' +
    $Bitmap.Height + '" role="img" aria-label="' + $Label + '"><image width="' +
    $Bitmap.Width + '" height="' + $Bitmap.Height +
    '" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,' +
    $base64 + '"/></svg>'
  [IO.File]::WriteAllText((Join-Path (Get-Location) $Path), $svg, [Text.UTF8Encoding]::new($false))
}

$clientBitmap = Read-EmbeddedBitmap $Client
try {
  Remove-ConnectedWhitespace $clientBitmap
  if ($LibeRalityOnly) {
    $liberalityBitmap = [Drawing.Bitmap]$clientBitmap.Clone()
    try {
      Convert-BlueToAmber $liberalityBitmap
      Write-EmbeddedSvg $liberalityBitmap $LibeRality "liberality-amber" "LibeRality"
    } finally { $liberalityBitmap.Dispose() }
    return
  }

  if (-not $LibeRatorOnly -and -not $LibeRtADOnly) {
    $libraryBitmap = [Drawing.Bitmap]$clientBitmap.Clone()
    try {
      Convert-BlueToGreen $libraryBitmap
      foreach ($libraryPath in $Library) {
        Write-EmbeddedSvg $libraryBitmap $libraryPath "liberary-green" "LibeRary"
      }
    } finally { $libraryBitmap.Dispose() }
  }

  if (-not $LibraryOnly) {
    if (-not $LibeRatorOnly -and -not $LibeRtADOnly) {
      Write-EmbeddedSvg $clientBitmap $Client "liberation-blue" "LibeRation"
    }
    if (-not $LibeRtADOnly) {
      $liberatorBitmap = [Drawing.Bitmap]$clientBitmap.Clone()
      try {
        Convert-BlueToTeal $liberatorBitmap
        Write-EmbeddedSvg $liberatorBitmap $LibeRator "liberator-teal" "LibeRator"
      } finally { $liberatorBitmap.Dispose() }
    }
    if (-not $LibeRatorOnly) {
      $libertadBitmap = [Drawing.Bitmap]$clientBitmap.Clone()
      try {
        Convert-BlueToPurple $libertadBitmap
        Write-EmbeddedSvg $libertadBitmap $LibeRtAD "libertad-purple" "LibeRtAD"
      } finally { $libertadBitmap.Dispose() }
    }
    if (-not $LibeRatorOnly -and -not $LibeRtADOnly) {
      $serverBitmap = [Drawing.Bitmap]$clientBitmap.Clone()
      try {
        Convert-BlueToRed $serverBitmap
        Write-EmbeddedSvg $serverBitmap $Server "liberties-red" "LibeRties"
      } finally { $serverBitmap.Dispose() }
    }
  }

  if (-not $LibraryOnly -and -not $LibeRatorOnly -and -not $LibeRtADOnly) {
    $liberalityBitmap = [Drawing.Bitmap]$clientBitmap.Clone()
    try {
      Convert-BlueToAmber $liberalityBitmap
      Write-EmbeddedSvg $liberalityBitmap $LibeRality "liberality-amber" "LibeRality"
    } finally { $liberalityBitmap.Dispose() }
  }
} finally { $clientBitmap.Dispose() }
