# Script para ejecutar todos los tests de mapas en PowerShell

$ejecutable = "..\ejercicio2.ps1"   # ruta al script principal
$pruebasDir = "."                   # carpeta actual (donde están mapaX.txt)
$outDir = ".\salidas_ps"

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

Get-ChildItem $pruebasDir -Filter "mapa*.txt" | ForEach-Object {
    $nombre = $_.BaseName
    Write-Host ">>> Ejecutando pruebas para $nombre"

    # Hub
    & $ejecutable -matriz $_.FullName -hub
    Move-Item -Force "$($_.DirectoryName)\informe.$($_.Name)" "$outDir\${nombre}_hub.txt"

    # Camino más corto
    & $ejecutable -matriz $_.FullName -camino
    Move-Item -Force "$($_.DirectoryName)\informe.$($_.Name)" "$outDir\${nombre}_camino.txt"
}

Write-Host "Todas las pruebas ejecutadas. Resultados en $outDir"
