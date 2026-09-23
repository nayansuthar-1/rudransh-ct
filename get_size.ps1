Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('d:\Nayan\rudransh\final.png')
Write-Host "Width: $($img.Width), Height: $($img.Height)"
$img.Dispose()
