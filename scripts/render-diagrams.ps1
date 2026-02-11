# Renders DOT files in the `diagrams` folder to PNG/SVG using graphviz `dot`.
# Usage: ./scripts/render-diagrams.ps1

$dot = (Get-Command dot -ErrorAction SilentlyContinue)
if (-not $dot) {
  Write-Error "Graphviz 'dot' not found. Install Graphviz and ensure 'dot' is in PATH. https://graphviz.org/download/"
  exit 1
}

$files = Get-ChildItem -Path "..\diagrams" -Filter *.dot -File
foreach ($f in $files) {
  $png = "$($f.Directory.FullName)\$($f.BaseName).png"
  $svg = "$($f.Directory.FullName)\$($f.BaseName).svg"
  Write-Host "Rendering $($f.Name) -> $($png) and $($svg)"
  dot -Tpng $f.FullName -o $png
  dot -Tsvg $f.FullName -o $svg
}
