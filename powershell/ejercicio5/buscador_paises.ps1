<#
.SYNOPSIS
    Busca información de países usando la API REST Countries con caché.

.DESCRIPTION
    USO:
      ./buscador_paises.ps1 -nombre "pais1","pais2",... -ttl SEGUNDOS

    PARÁMETROS:
      -nombre    Nombre(s) de país a buscar (obligatorio)
      -ttl       Tiempo en segundos que durará el caché (obligatorio)

    EJEMPLO:
      ./buscador_paises.ps1 -nombre "Spain","Argentina" -ttl 3600
      ./buscador_paises.ps1 -nombre "Uruguay" -ttl 60

    Este script consulta la API: https://restcountries.com/v3.1/name/{nombre}
    Los resultados se guardan en caché en el directorio temporal del sistema.
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$nombre,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$ttl
)

$cacheFile = $null

try {
    # Determinar directorio temporal según el sistema operativo
    function Get-TempDirectory {
        if ($IsWindows -or $env:OS -match "Windows") {
            if ([string]::IsNullOrEmpty($env:TEMP)) {
                throw "No se pudo determinar el directorio temporal"
            }
            return $env:TEMP
        } else {
            if (-not [string]::IsNullOrEmpty($env:TMPDIR)) {
                return $env:TMPDIR
            } elseif (Test-Path "/tmp") {
                return "/tmp"
            } else {
                throw "No se pudo determinar el directorio temporal"
            }
        }
    }

    $tempDir = Get-TempDirectory
    $cacheFile = Join-Path -Path $tempDir -ChildPath "paises_cache.json"

    # Carga el caché desde disco
    function Load-Cache {
        if (Test-Path $cacheFile) {
            try {
                $raw = Get-Content $cacheFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $ht = @{}
                foreach ($prop in $raw.PSObject.Properties) {
                    $ht[$prop.Name] = $prop.Value
                }
                return $ht
            } catch {
                Write-Warning "El archivo de caché estaba corrupto, se creará uno nuevo."
                return @{}
            }
        } else {
            return @{}
        }
    }

    # Guarda el caché en disco
    function Save-Cache {
        param([hashtable]$cache)
        try {
            $cache | ConvertTo-Json -Depth 5 | Set-Content $cacheFile -ErrorAction Stop
        } catch {
            throw "No se pudo guardar el archivo de caché: $_"
        }
    }

    # Obtiene información de un país desde la API
    function Get-PaisData {
        param([string]$pais)
        
        try {
            $url = "https://restcountries.com/v3.1/name/$pais"
            $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            
            if ($response.Count -gt 0) {
                $country = $response[0]
                
                $capital = "N/A"
                if ($country.capital -and $country.capital.Count -gt 0) {
                    $capital = $country.capital -join ", "
                }
                
                $moneda = "N/A"
                if ($country.currencies -and $country.currencies.PSObject.Properties.Count -gt 0) {
                    $currencyKey = $country.currencies.PSObject.Properties.Name | Select-Object -First 1
                    $currencyObj = $country.currencies.$currencyKey
                    $moneda = "$($currencyObj.name) ($currencyKey)"
                }
                
                return [PSCustomObject]@{
                    nombre    = $country.name.common
                    capital   = $capital
                    region    = $country.region
                    poblacion = $country.population
                    moneda    = $moneda
                }
            } else {
                throw "No se encontraron resultados"
            }
        } catch {
            if ($_.Exception.Message -match "404") {
                Write-Host " No se encontró el país '$pais'. Verifique el nombre." -ForegroundColor Red
            } else {
                Write-Host " Error al consultar '$pais': Verifique su conexión a internet." -ForegroundColor Red
            }
            return $null
        }
    }

    # Muestra la información del país
    function Show-PaisInfo {
        param([PSCustomObject]$data)
        
        Write-Host "-----------------------------------"
        Write-Host "País:      $($data.nombre)" -ForegroundColor Green
        Write-Host "Capital:   $($data.capital)"
        Write-Host "Región:    $($data.region)"
        Write-Host "Población: $($data.poblacion)"
        Write-Host "Moneda:    $($data.moneda)"
    }

    # Cargar caché
    $cache = Load-Cache

    # Procesar cada país
    foreach ($pais in $nombre) {
        $paisKey = $pais.ToLower().Trim()
        $usarCache = $false
        $data = $null

        if ($cache.ContainsKey($paisKey)) {
            $entry = $cache[$paisKey]
            try {
                $timestamp = [datetime]$entry.timestamp
                $age = (Get-Date) - $timestamp
                
                if ($age.TotalSeconds -lt $ttl) {
                    $usarCache = $true
                    $data = $entry.data
                    Write-Host "  Desde caché: '$pais'" 
                }
            } catch {
                Write-Warning "Datos de caché inválidos para '$pais'."
            }
        }

        if (-not $usarCache) {
            Write-Host "--- Consultando API: '$pais'..."
            $data = Get-PaisData -pais $pais
            
            if ($data) {
                $cache[$paisKey] = @{
                    timestamp = (Get-Date).ToString("o")
                    data      = $data
                }
                Save-Cache $cache
            }
        }

        if ($data) {
            Show-PaisInfo -data $data
        }
    }

    Write-Host "`n--- Proceso completado." -ForegroundColor Green

} catch {
    Write-Host "`n--- Error: Ocurrió un problema al ejecutar el script." -ForegroundColor Red
    Write-Host "Detalles: $_"
    exit 1
} finally {
    # El caché persiste intencionalmente
}