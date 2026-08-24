<# INTEGRANTES: Grupo 6
    VALLE,RAMIRO
    PARRA, IGNACIO
    CATARI EZEQUIEL MOHAMED
    BLANCO, VICTORIA MARIEL
    ALTAMIRANO, FABRIZIO AUGUSTO
 #>

<#
.SYNOPSIS
Ejercicio 3 - Conteo de eventos en logs de sistemas

.DESCRIPTION
Analiza todos los archivos .log en un directorio y cuenta la ocurrencia
de palabras clave dadas por el usuario. La búsqueda es case-insensitive.

.PARAMETER Directorio
Ruta del directorio que contiene los archivos .log a analizar.

.PARAMETER Palabras
Lista de palabras clave a contabilizar. Ejemplo: -palabras "usb","invalid"

.EXAMPLE
PS> ./ejercicio3.ps1 -directorio ./logs -palabras "usb","invalid"

.EXAMPLE
PS> Get-Help ./ejercicio3.ps1
Muestra la ayuda de este script.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Directorio,

    [Parameter(Mandatory = $true)]
    [string[]]$Palabras
)

function Mostrar-Error {
    param([string]$Mensaje)
    Write-Host "Error: $Mensaje" -ForegroundColor Red
    exit 1
}

try {
    # Validar directorio
    if (-not (Test-Path $Directorio)) {
        Mostrar-Error "El directorio '$Directorio' no existe."
    }

    # Buscar archivos .log
    $archivos = Get-ChildItem -Path $Directorio -Filter *.log -ErrorAction Stop
    if ($archivos.Count -eq 0) {
        Mostrar-Error "No se encontraron archivos .log en '$Directorio'."
    }

    # Crear un hashtable para contar
    $contador = @{}
    foreach ($p in $Palabras) {
        $contador[$p] = 0
    }

    # Procesar archivos
    foreach ($archivo in $archivos) {
        $lineas = Get-Content $archivo.FullName
        foreach ($linea in $lineas) {
            foreach ($p in $Palabras) {
                # Comparación case-insensitive
                $matches = [regex]::Matches($linea, [regex]::Escape($p), "IgnoreCase")
                $contador[$p] += $matches.Count
            }
        }
    }

    # Mostrar resultados nuevo
    foreach ($p in $Palabras) {
    Write-Host "${p}: $($contador[$p])"
    }

} catch {
    Mostrar-Error "Ocurrió un error inesperado: $_"
} finally {
    # Acá podrías limpiar archivos temporales si los hubiera
}
