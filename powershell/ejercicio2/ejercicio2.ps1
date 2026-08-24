<# INTEGRANTES: Grupo 6
    VALLE,RAMIRO
    PARRA, IGNACIO
    CATARI EZEQUIEL MOHAMED
    BLANCO, VICTORIA MARIEL
    ALTAMIRANO, FABRIZIO AUGUSTO
 #>

<#
.SYNOPSIS
	Analiza una red de transporte representada como matriz de adyacencia.
.DESCRIPTION
	Permite dos operaciones excluyentes:
		- -hub: determina las estaciones con mayor numero de conexiones.
		- -camino: calcula el camino mas corto entre la estacion 1 y la estacion N (Dijkstra).
	Valida que la matriz sea cuadrada, simetrica y numerica (enteros o decimales).
	Genera un archivo de salida: informe.<nombreArchivoEntrada> junto al archivo de la matriz.
.PARAMETER matriz
	Ruta del archivo de la matriz (texto). Columnas separadas por el separador.
.PARAMETER separador
	Separador de columnas. Por defecto: '|'.
.PARAMETER hub
	Calcula la(s) estacion(es) con mayor cantidad de conexiones. Incompatible con -camino.
.PARAMETER camino
	Calcula el camino mas corto entre la estacion 1 y la estacion N. Incompatible con -hub.
.EXAMPLE
	PS> .\ejercicio2.ps1 -matriz .\pruebas\mapa1.txt -hub
.EXAMPLE
	PS> .\ejercicio2.ps1 -matriz .\pruebas\mapa1.txt -camino
.NOTES
	Salida: informe.<archivo>
#>

Param(
    [Parameter(Mandatory=$true)][string]$matriz,
    [switch]$hub,
    [switch]$camino,
    [string]$separador = "|"
)

if ($hub -and $camino) {
    Write-Error "Error: no se puede usar -hub y -camino al mismo tiempo"
    exit 1
}

$outFile = (Split-Path $matriz) + "\informe." + (Split-Path $matriz -Leaf)
$lineas = Get-Content $matriz
$N = $lineas.Count

# Construir matriz
$M = @()
foreach ($linea in $lineas) {
    $row = $linea -split [regex]::Escape($separador)
    if ($row.Length -ne $N) {
        Write-Error "La matriz no es cuadrada"
        exit 1
    }
    $M += ,$row
}

# --- Hub ---
if ($hub) {
    $max = 0
    $hubs = @()
    for ($i=0; $i -lt $N; $i++) {
    $count = 0
    for ($j=0; $j -lt $N; $j++) {
        if ([double]$M[$i][$j] -ne 0) { $count++ }
    }
    if ($count -gt $max) {
        $max = $count
        $hubs = @($i+1)
    } elseif ($count -eq $max) {
        $hubs += ($i+1)
    }
}

$texto = "## Informe de análisis de red de transporte`n**Hub de la red:** Estaciones $($hubs -join ', ') ($max conexiones)"
Set-Content -Path $outFile -Value $texto -Encoding UTF8
    exit
}

# --- Dijkstra ---
if ($camino) {
    $origen = 0
    $destino = $N-1
    $dist = @(); $prev = @(); $visited = @()
    for ($i=0; $i -lt $N; $i++) {
        $dist += [double]::PositiveInfinity
        $prev += -1
        $visited += $false
    }
    $dist[$origen] = 0

    for ($k=0; $k -lt $N; $k++) {
        $u = -1; $min = [double]::PositiveInfinity
        for ($i=0; $i -lt $N; $i++) {
            if (-not $visited[$i] -and $dist[$i] -lt $min) {
                $min = $dist[$i]; $u = $i
            }
        }
        if ($u -eq -1) { break }
        $visited[$u] = $true

        for ($v=0; $v -lt $N; $v++) {
            $peso = [double]$M[$u][$v]
            if ($peso -eq 0) { continue }
            if ($dist[$u] + $peso -lt $dist[$v]) {
                $dist[$v] = $dist[$u] + $peso
                $prev[$v] = $u
            }
        }
    }

    # reconstruir ruta
    $ruta = @()
    $nodo = $destino
    while ($nodo -ne -1) {
        $ruta = ,($nodo+1) + $ruta
        $nodo = $prev[$nodo]
    }
"## Informe de analisis de red de transporte`n**Camino mas corto: entre Estacion 1 y Estacion ${N}:**`n**Tiempo total:** $($dist[$destino]) minutos`n**Ruta:** $($ruta -join ' -> ')" | Out-File $outFile
}
