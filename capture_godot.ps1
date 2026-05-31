Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing,System.Windows.Forms @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Imaging;

public class WinCap {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

    public static void Snap(string title, string outPath) {
        IntPtr h = FindWindow(null, title);
        if (h == IntPtr.Zero) { Console.WriteLine("Window not found: " + title); return; }
        ShowWindow(h, 9); // SW_RESTORE
        SetForegroundWindow(h);
        System.Threading.Thread.Sleep(400);
        RECT r; GetWindowRect(h, out r);
        int w = r.Right - r.Left, ht = r.Bottom - r.Top;
        var bmp = new Bitmap(w, ht);
        using (var g = Graphics.FromImage(bmp)) {
            g.CopyFromScreen(r.Left, r.Top, 0, 0, new Size(w, ht));
        }
        bmp.Save(outPath, ImageFormat.Png);
        Console.WriteLine("Saved " + outPath);
    }
}
"@
[WinCap]::Snap('Facetbound (DEBUG)', 'C:\Users\cozmu\projects\Diceforge\godot_capture.png')
