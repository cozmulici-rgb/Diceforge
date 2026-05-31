# Recolor the OpenGameArt CC0 d{N}_Numbers.png textures from white-on-grey
# into the dark-obsidian-with-gold-numbers occult aesthetic shown in the
# reference image (matte black metal body, bright gold numerals, dim gold
# edge accents, and fine gold "engraving" filigree across each face).
#
# Per-pixel base mapping (grayscale average of the source):
#   - very dark  (avg <  80)  -> dim gold edge accent (draws face boundaries)
#   - mid grey   (80-235)     -> dark obsidian base    (face fill)
#   - near white (avg >= 235) -> bright gold           (numbers)
#
# Then an ornament pass paints fine dim-gold crackle veins + star sparkles,
# masked to the obsidian face-fill regions only (never over numerals or the
# out-of-UV background), giving the engraved occult filigree look.

Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

public static class DiceRecolor {
    // Palette (RGB)
    //  Base obsidian: (22, 22, 28)
    //  Bright gold:   (212, 165, 53)   numerals
    //  Dim gold edge: (110, 84, 24)    face boundaries
    //  Filigree gold: (150, 116, 40)   engraving veins / sparkles
    static byte baseR = 22,  baseG = 22,  baseB = 28;
    static byte goldR = 212, goldG = 165, goldB = 53;
    static byte dimR  = 110, dimG  = 84,  dimB  = 24;
    static byte filR  = 150, filG  = 116, filB  = 40;

    public static void Process(string inputPath, string outputPath, bool ornament, int seed) {
        Bitmap bmp;
        using (var src = (Bitmap)Image.FromFile(inputPath)) {
            bmp = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
            using (var gfx = Graphics.FromImage(bmp)) { gfx.DrawImageUnscaled(src, 0, 0); }
        }
        int W = bmp.Width, H = bmp.Height;

        // --- read source luminance & build face-fill mask ---
        var rect = new Rectangle(0, 0, W, H);
        var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int len = data.Stride * H;
        byte[] buf = new byte[len];
        Marshal.Copy(data.Scan0, buf, 0, len);

        bool[] faceMask = new bool[W * H];   // true where source was mid-grey face fill
        for (int i = 0, px = 0; i < len; i += 4, px++) {
            int avg = (buf[i] + buf[i + 1] + buf[i + 2]) / 3;
            if (avg >= 235)      { buf[i]=goldB; buf[i+1]=goldG; buf[i+2]=goldR; }
            else if (avg < 80)   { buf[i]=dimB;  buf[i+1]=dimG;  buf[i+2]=dimR;  }
            else                 { buf[i]=baseB; buf[i+1]=baseG; buf[i+2]=baseR; faceMask[px]=true; }
            buf[i + 3] = 255;
        }
        Marshal.Copy(buf, 0, data.Scan0, len);
        bmp.UnlockBits(data);

        // --- ornament layer: fine gold filigree drawn on a black scratch bitmap ---
        if (ornament) {
            using (var orn = new Bitmap(W, H, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(orn)) {
                g.Clear(Color.Black);
                g.SmoothingMode = SmoothingMode.AntiAlias;
                var rnd = new Random(seed);
                Color gold = Color.FromArgb(255, filR, filG, filB);

                // Crackle veins: jagged random-walk polylines.
                int veins = (W * H) / 90000;            // ~46 on a 2048^2 sheet
                using (var pen = new Pen(gold, Math.Max(2f, W / 900f))) {
                    pen.LineJoin = LineJoin.Round;
                    for (int v = 0; v < veins; v++) {
                        float x = rnd.Next(W), y = rnd.Next(H);
                        float ang = (float)(rnd.NextDouble() * Math.PI * 2);
                        int segs = 4 + rnd.Next(6);
                        for (int s = 0; s < segs; s++) {
                            float nlen = W / 60f + rnd.Next(W / 40);
                            ang += (float)((rnd.NextDouble() - 0.5) * 1.4);
                            float nx = x + (float)Math.Cos(ang) * nlen;
                            float ny = y + (float)Math.Sin(ang) * nlen;
                            g.DrawLine(pen, x, y, nx, ny);
                            x = nx; y = ny;
                        }
                    }
                }

                // Star sparkles: 4-point gold asterisks scattered about.
                int stars = (W * H) / 140000;           // ~30
                using (var pen = new Pen(gold, Math.Max(1.5f, W / 1300f))) {
                    for (int s = 0; s < stars; s++) {
                        float cx = rnd.Next(W), cy = rnd.Next(H);
                        float r = W / 120f + rnd.Next(W / 90);
                        g.DrawLine(pen, cx - r, cy, cx + r, cy);
                        g.DrawLine(pen, cx, cy - r, cx, cy + r);
                        float d = r * 0.6f;
                        g.DrawLine(pen, cx - d, cy - d, cx + d, cy + d);
                        g.DrawLine(pen, cx - d, cy + d, cx + d, cy - d);
                    }
                }

                // Composite ornament onto buf where face-fill AND ornament is bright.
                var od = orn.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                byte[] obuf = new byte[len];
                Marshal.Copy(od.Scan0, obuf, 0, len);
                orn.UnlockBits(od);

                var d2 = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
                Marshal.Copy(d2.Scan0, buf, 0, len);
                for (int i = 0, px = 0; i < len; i += 4, px++) {
                    if (!faceMask[px]) continue;
                    float a = obuf[i + 2] / 255f;        // red channel of gold ~ coverage
                    if (a < 0.04f) continue;
                    buf[i]   = (byte)(buf[i]   + (filB - buf[i])   * a);
                    buf[i+1] = (byte)(buf[i+1] + (filG - buf[i+1]) * a);
                    buf[i+2] = (byte)(buf[i+2] + (filR - buf[i+2]) * a);
                }
                Marshal.Copy(buf, 0, d2.Scan0, len);
                bmp.UnlockBits(d2);
            }
        }

        bmp.Save(outputPath, ImageFormat.Png);
        bmp.Dispose();
    }
}
"@

$texDir  = 'C:\Users\cozmu\projects\Diceforge\game\assets\dice\meshes_textured\textures'
$diceDir = 'C:\Users\cozmu\projects\Diceforge\game\assets\dice'

# Back up originals once (skip if backup already exists)
$backupRoot = Join-Path $diceDir '_backup_original_textures'
if (-not (Test-Path $backupRoot)) {
    New-Item -ItemType Directory -Path $backupRoot | Out-Null
    Copy-Item -Path "$texDir\*.png" -Destination $backupRoot
    Copy-Item -Path "$diceDir\diffuse-dark.png" -Destination $backupRoot
    Copy-Item -Path "$diceDir\diffuse-light.png" -Destination $backupRoot
    Write-Output "Backed up originals -> $backupRoot"
}

# Always recolor from the pristine backup so re-runs are idempotent.
$seed = 1337
foreach ($sides in 4, 6, 8, 10, 12, 20) {
    $src = "$backupRoot\d${sides}_Numbers.png"
    $dst = "$texDir\d${sides}_Numbers.png"
    if (Test-Path $src) {
        Write-Output "Recoloring d${sides}_Numbers.png ..."
        [DiceRecolor]::Process($src, $dst, $true, ($seed + $sides))
    }
}

# Recolor the legacy diffuse textures (no ornament; they are body fills).
foreach ($variant in 'diffuse-dark', 'diffuse-light') {
    $src = "$backupRoot\$variant.png"
    $dst = "$diceDir\$variant.png"
    if (Test-Path $src) {
        Write-Output "Recoloring $variant.png ..."
        [DiceRecolor]::Process($src, $dst, $false, $seed)
    }
}

Write-Output "Done."
