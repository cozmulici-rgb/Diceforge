# Recolor the OpenGameArt CC0 d{N}_Numbers.png textures from white-on-grey
# into the dark-black-with-gold-numbers aesthetic shown in the reference image.
#
# Mapping (per pixel, using grayscale average):
#   - very dark  (avg <  80)  → gold edge accent  (dim gold, draws face boundaries)
#   - light grey (80–235)     → dark obsidian base (face fill)
#   - near white (avg ≥ 235)  → bright gold       (numbers + UV bleed)
#
# Outside-UV pixels are sampled by the mesh's UV unwrap only inside the face
# polygons, so painting them gold has no visible effect on the rendered die.

Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class DiceRecolor {
    public static void Process(string inputPath, string outputPath) {
        // Read into a fresh in-memory Bitmap so the file handle on inputPath
        // is released before we save (allows in-place overwrite).
        Bitmap bmp;
        using (var src = (Bitmap)Image.FromFile(inputPath)) {
            bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
            using (var gfx = Graphics.FromImage(bmp)) {
                gfx.DrawImageUnscaled(src, 0, 0);
            }
        }
        using (bmp) {
            var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
            var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            int len = data.Stride * bmp.Height;
            byte[] buf = new byte[len];
            Marshal.Copy(data.Scan0, buf, 0, len);

            // Palette (BGRA byte order in System.Drawing's 32bppArgb layout)
            //  Base obsidian: RGB(22, 22, 28)
            //  Gold:          RGB(212, 165, 53)
            //  Dim gold edge: RGB(110, 84, 24)
            byte baseB = 28,  baseG = 22,  baseR = 22;
            byte goldB = 53,  goldG = 165, goldR = 212;
            byte dimB  = 24,  dimG  = 84,  dimR  = 110;

            for (int i = 0; i < len; i += 4) {
                int b = buf[i];
                int g = buf[i + 1];
                int r = buf[i + 2];
                int avg = (r + g + b) / 3;

                if (avg >= 235) {
                    buf[i] = goldB; buf[i + 1] = goldG; buf[i + 2] = goldR;
                } else if (avg < 80) {
                    buf[i] = dimB;  buf[i + 1] = dimG;  buf[i + 2] = dimR;
                } else {
                    buf[i] = baseB; buf[i + 1] = baseG; buf[i + 2] = baseR;
                }
                buf[i + 3] = 255;
            }

            Marshal.Copy(buf, 0, data.Scan0, len);
            bmp.UnlockBits(data);
            bmp.Save(outputPath, ImageFormat.Png);
        }
    }
}
"@

$texDir   = 'C:\Users\cozmu\projects\Diceforge\game\assets\dice\meshes_textured\textures'
$diceDir  = 'C:\Users\cozmu\projects\Diceforge\game\assets\dice'

# Back up originals once (skip if backup already exists)
$backupRoot = Join-Path $diceDir '_backup_original_textures'
if (-not (Test-Path $backupRoot)) {
    New-Item -ItemType Directory -Path $backupRoot | Out-Null
    Copy-Item -Path "$texDir\*.png" -Destination $backupRoot
    Copy-Item -Path "$diceDir\diffuse-dark.png" -Destination $backupRoot
    Copy-Item -Path "$diceDir\diffuse-light.png" -Destination $backupRoot
    Write-Output "Backed up originals → $backupRoot"
}

# Recolor each numbered UV texture
foreach ($sides in 4, 6, 8, 10, 12, 20) {
    $src = "$texDir\d${sides}_Numbers.png"
    if (Test-Path $src) {
        Write-Output "Recoloring d${sides}_Numbers.png ..."
        [DiceRecolor]::Process($src, $src)
    }
}

# Recolor the legacy diffuse textures
foreach ($variant in 'diffuse-dark', 'diffuse-light') {
    $src = "$diceDir\$variant.png"
    if (Test-Path $src) {
        Write-Output "Recoloring $variant.png ..."
        [DiceRecolor]::Process($src, $src)
    }
}

Write-Output "Done."
