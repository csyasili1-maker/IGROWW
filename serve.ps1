# serve.ps1 - Native PowerShell static file web server
$port = 8765
$localAddress = "http://localhost:$port/"
$webRoot = Get-Location

# MIME types mapping
$mimeTypes = @{
    ".html"  = "text/html; charset=utf-8"
    ".htm"   = "text/htm; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".js"    = "application/javascript; charset=utf-8"
    ".json"  = "application/json; charset=utf-8"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".gif"   = "image/gif"
    ".svg"   = "image/svg+xml"
    ".webp"  = "image/webp"
    ".ico"   = "image/x-icon"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
    ".otf"   = "font/otf"
    ".eot"   = "application/vnd.ms-fontobject"
    ".xml"   = "application/xml; charset=utf-8"
    ".txt"   = "text/plain; charset=utf-8"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($localAddress)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     LATE I GROWW LOCAL WEB SERVER" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Starting server on: $localAddress" -ForegroundColor Yellow
Write-Host "Web Root: $($webRoot.Path)" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan

try {
    $listener.Start()
} catch {
    Write-Host "Error: Failed to start listener on port $port. Is the port already in use?" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit
}

# Open the website in the default browser
Start-Process $localAddress

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Determine path
        $urlPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
        if ($urlPath -eq "/") {
            $urlPath = "/index.html"
        }

        # Combine with web root and clean path separators
        $localPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($webRoot.Path, $urlPath.TrimStart('/')))

        # Security check: Ensure requested path is within the web root folder
        if (-not $localPath.StartsWith($webRoot.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "Blocked potential path traversal request: $urlPath" -ForegroundColor Red
            $response.StatusCode = 403
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            continue
        }

        if (Test-Path $localPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($localPath).ToLower()
            $contentType = $mimeTypes[$ext]
            if (-not $contentType) {
                $contentType = "application/octet-stream"
            }
            $response.ContentType = $contentType
            $response.StatusCode = 200
            $response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
            $response.Headers.Add("Pragma", "no-cache")
            $response.Headers.Add("Expires", "0")

            # Read and write file
            $fileStream = [System.IO.File]::OpenRead($localPath)
            $response.ContentLength64 = $fileStream.Length
            
            # Copy to output stream in chunks
            $buffer = New-Object byte[] 64kb
            while (($bytesRead = $fileStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $response.OutputStream.Write($buffer, 0, $bytesRead)
            }
            $fileStream.Close()
            Write-Host "200 OK: $urlPath" -ForegroundColor Green
        } else {
            Write-Host "404 Not Found: $urlPath" -ForegroundColor Red
            $response.StatusCode = 404
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        $response.OutputStream.Close()
    } catch {
        # Handle exceptions gracefully (e.g. client disconnect)
        Write-Host "Request error: $_" -ForegroundColor DarkYellow
    }
}
