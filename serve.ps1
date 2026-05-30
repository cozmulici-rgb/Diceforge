$port = if ($env:PORT) { $env:PORT } else { '8734' }
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $local = $req.Url.LocalPath
    if ($local -eq '/') { $local = '/test_roll.html' }
    $path = "C:\Users\cozmu\projects\Diceforge" + $local.Replace('/', '\')
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $ext = [System.IO.Path]::GetExtension($path)
        $res.ContentType = switch ($ext) {
            '.html' { 'text/html; charset=utf-8' }
            '.js'   { 'application/javascript' }
            '.css'  { 'text/css' }
            '.png'  { 'image/png' }
            default { 'application/octet-stream' }
        }
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
        $res.StatusCode = 404
    }
    $res.Close()
}
