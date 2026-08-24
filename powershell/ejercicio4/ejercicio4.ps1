<#
.SYNOPSIS
    Monitorea un directorio y registra una alerta en un archivo de log con el nombre del archivo, el patrón encontrado y la fecha.

.DESCRIPTION
    MATERIA: Virtualizacion de Hardware.
    COMISION: 02 - 4900
    GRUPO: 6
    ALUMNOS:
        - ALTAMIRANO, FABRIZIO AUGUSTO
        - BLANCO, VICTORIA MARIEL
        - CATARI EZEQUIEL MOHAMED
        - PARRA, IGNACIO
        - VALLE,RAMIRO

    Monitorea un directorio y registra una alerta en un archivo de log con el nombre del archivo, el patrón encontrado y la fecha.

.PARAMETER Repositorio
    Ruta del repositorio Git a monitorear. Obligatorio

.PARAMETER Configuracion
    Ruta del archivo de configuración que contiene la lista de patrones a buscar. Obligatorio

.PARAMETER Log
    Ruta del archivo de logs que contiene la lista de eventos identificados. Obligatorio

.PARAMETER Kill
    Flag para detener el demonio. Solo se usa junto con -repo

.EXAMPLE
    ./ejercicio4.ps1 -repo /home/user/myrepo -configuracion ./patrones.conf -log ./patrones.log
    Crea el demonio para el directorio /home/user/myrepo, utiliza los patrones contenidos en ./patrones.conf para buscar cambios y los loggea en ./patrones.log

.EXAMPLE
    ./ejercicio4.ps1 -repo /home/user/myrepo -kill
    Mata al demonio que observaba al directorio /home/user/myrepo
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path -PathType Container $_})]
    [string]$repo,

    [Parameter(Mandatory = $false)]
    [string]$configuracion,

    [Parameter(Mandatory = $false)]
    [string]$log,

    [switch]$kill
)

$nombre = Split-Path -Path $repo -Leaf
$pidFile = Join-Path -Path $HOME -ChildPath "demonio_${nombre}.pid"

if ($Kill) {
    if (Test-Path $pidFile) {
        $jobId = Get-Content $pidFile
        $job = Get-Job | Where-Object { $_.Id -eq $jobId }
        if ($job) {
            Stop-Job $job
            Remove-Job $job
            Remove-Item $pidFile
            Write-Host "[INFO] Demonio detenido para '$repo'."
        } else {
            Write-Host "[WARNING] No se encontro el job activo. Eliminando PID obsoleto."
            Remove-Item $pidFile
        }
    } else {
        Write-Host "[ERROR] No hay un demonio corriendo para '$repo'."
    }
    exit
}

# Validaciones de parametros si no se usa -Kill
if (-not $configuracion) {
    Write-Host "[ERROR] Debe especificar un archivo de configuracion." -ForegroundColor Red
    exit 1
}
if (-not $log) {
    Write-Host "[ERROR] Debe especificar un archivo de log." -ForegroundColor Red
    exit 1
}

# Si ya existe un demonio para este directorio
if (Test-Path $pidFile) {
    $jobId = Get-Content $pidFile
    $job = Get-Job | Where-Object { $_.Id -eq $jobId }
    if ($job) {
        Write-Host "[ERROR] Ya hay un demonio ejecutandose para '$repo'." -ForegroundColor Red
        exit 1
    } else {
        Remove-Item $pidFile
    }
}

# Iniciar el demonio en segundo plano
$job = Start-Job -ScriptBlock {
param ($repo, $configuracion, $log)

function Write-Alert {
    param(
        [string]$Pattern,
        [string]$File,
        [string]$MatchedLine
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = if ($MatchedLine) {
        "[{0}] Alerta: patrón '{1}' encontrado en el archivo '{2}' — {3}" -f $timestamp, $Pattern, $File, $MatchedLine.Trim()
    } else {
        "[{0}] Alerta: patrón '{1}' encontrado en el archivo '{2}'" -f $timestamp, $Pattern, $File
    }
    Add-Content -Path $log -Value $entry
}

function Get-Patterns {
    param([string]$File)
    Get-Content $File |
        ForEach-Object {
            $_.Trim()
        } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
}

$global:Patterns = Get-Patterns -File $configuracion
$global:LastEvent = @{}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = (Resolve-Path $repo)
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite

$action = {
    $filePath = $Event.SourceEventArgs.FullPath
    $now = Get-Date
    if (-not (Test-Path $filePath)) { return }  # si el archivo ya no existe

    if ($global:LastEvent.ContainsKey($filePath)) {
        $last = $global:LastEvent[$filePath]
        if (($now - $last).TotalMilliseconds -lt 500) {
            return   # ignorar evento duplicado
        }
    }
    $global:LastEvent[$filePath] = $now

    if ((Resolve-Path $filePath) -eq (Resolve-Path $using:configuracion)) {
        $global:Patterns = Get-Patterns -File $using:configuracion
        return
    }

    try {
        $content = Get-Content $filePath -ErrorAction Stop
        foreach ($pattern in $global:Patterns) {
            if ($pattern -match "^regex:") {
                $regex = $pattern.Substring(6)
                foreach ($line in $content) {
                    if ($line -match $regex) {
                        Write-Alert -Pattern $pattern -File $filePath -MatchedLine $line
                        break
                    }
                }
            }
            else {
                foreach ($line in $content) {
                    if ($line -like "*$pattern*") {
                        Write-Alert -Pattern $pattern -File $filePath -MatchedLine $line
                        break
                    }
                }
            }
        }
    } catch {
        # Ignorar errores de lectura
    }
}

Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Created -Action $action | Out-Null
Register-ObjectEvent $watcher Renamed -Action $action | Out-Null

while ($true) { Start-Sleep -Seconds 2 }

} -ArgumentList $repo, $configuracion, $log

# Guardar el ID del job
Set-Content -Path $pidFile -Value $job.Id

Write-Host "[INFO] Monitoreando '$repo'. Log: $log"