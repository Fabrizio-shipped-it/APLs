<# INTEGRANTES: Grupo 6
    VALLE,RAMIRO
    PARRA, IGNACIO
    CATARI EZEQUIEL MOHAMED
    BLANCO, VICTORIA MARIEL
    ALTAMIRANO, FABRIZIO AUGUSTO
 #>

<#
.SYNOPSIS
   Analiza resultados de encuestas de satisfacción de clientes.
.DESCRIPTION
   Este script procesa archivos de texto tabulados (campos separados por '|') que contienen encuestas de satisfacción.
   Calcula promedios de tiempo de respuesta y nota de satisfacción, agrupados por fecha y por canal de atención .
   La salida puede mostrarse en pantalla o guardarse como archivo JSON.
.EXAMPLE
   .\ejercicio1.ps1 -directorio ./lote -pantalla
        Muestra el resultado en pantalla en formato JSON.
.EXAMPLE
   .\ejercicio1.ps1 -directorio ./lote -archivo resultados.json
        Guarda el resultado en el archivo 'resultados.json'.
.INPUTS
   Parámetros:
     -directorio (string): Ruta del directorio con archivos de encuestas.
     -archivo (string): Ruta del archivo JSON de salida (opcional).
     -pantalla (switch): Muestra la salida en pantalla (opcional).
.OUTPUTS
   JSON con estructura agrupada por fecha y canal, incluyendo promedios de tiempo de respuesta y nota de satisfacción.
.NOTES
   Formato esperado de cada línea en los archivos de entrada:
     ID_ENCUESTA|FECHA|CANAL|TIEMPO_RESPUESTA|NOTA_SATISFACCION

   Los parámetros -pantalla y -archivo son excluyentes: debe usarse solo uno.
.FUNCTIONALITY
   Estadísticas de atención al cliente
#>

Param(
    [Parameter(Mandatory=$True)][string]$directorio,
    [string]$archivo,
    [switch]$pantalla  #switch == boolean
)

function MostrarError($mensaje){
    Write-Host "Error:" $mensaje -ForegroundColor Red
    exit 1
}

function validarParametros {
    if(!(Test-Path $directorio)){
        MostrarError "El directorio $directorio no existe"
    }
    $archivosTxt = Get-ChildItem -Path $directorio -Filter *.txt
    if ($archivosTxt.Count -eq 0) {
        MostrarError "El directorio $directorio no contiene archivos .txt ." 
    }
    if($pantalla -and $archivo){
        MostrarError "No puede usar -archivo y -pantalla al mismo tiempo. Debe elegir una sola opcionde salida."
    }
    if(-not $pantalla -and -not $archivo){
        MostrarError "Debe elegir una opcion, -archivo <ruta> o -pantalla."
    }
    if ($archivo -and ([System.IO.Path]::GetExtension($archivo) -ne ".json")) {
        MostrarError "El archivo de salida debe tener extensión .json."
    }
    return $archivosTxt
}

function procesarArchivos($archivosTxt){
    #crear HashTable anidada 
    #ht con fechas y por cada fecha su ht con canales
    $datos = @{}
    foreach ($archivoTxt in $archivosTxt) {
        Get-Content $archivoTxt.FullName | ForEach-Object {
            $linea = $_ -split '\|'
            if ($linea.Count -ne 5) {
                MostrarError "Línea mal formateada en '$($archivoTxt.Name)': $_"
            }

            $fecha = $linea[1].Substring(0,10)
            $canal = $linea[2]
            $tiempo = [double]$linea[3]
            $nota = [int]$linea[4]

            if (-not $datos.ContainsKey($fecha)) {
                $datos[$fecha] = @{}
            }
            if (-not $datos[$fecha].ContainsKey($canal)) {
                $datos[$fecha][$canal] = @{
                    Tiempos = 0.0
                    Notas = 0
                    Contador = 0
                }
            }

            $datos[$fecha][$canal].Tiempos += $tiempo
            $datos[$fecha][$canal].Notas += $nota
            $datos[$fecha][$canal].Contador++
        }
    }
    return $datos
}

function formatearNumero($valor) {
    #sacarle el .0 a los enteros
    [int]$valor -eq $valor ? [int]$valor : [math]::Round($valor,2)
}

function calcularPromedio($datos){
    # Crear estructura final agrupada
    $resultado = [ordered]@{}
    foreach ($fecha in $datos.Keys | Sort-Object) {
        $resultado[$fecha] = [ordered]@{}
        foreach ($canal in $datos[$fecha].Keys | Sort-Object) {
            $info = $datos[$fecha][$canal]
            $resultado[$fecha][$canal] = [ordered]@{
                tiempo_respuesta_promedio  = formatearNumero($info.Tiempos / $info.Contador)
                nota_satisfaccion_promedio = formatearNumero($info.Notas / $info.Contador)
            }
        }
    }
    return $resultado
}

# ----------
$archivosTxt = validarParametros
$datos = procesarArchivos $archivosTxt
$resultado = calcularPromedio $datos

$json = $resultado | ConvertTo-Json -Depth 3
#------ Salida ------
if( $pantalla ){
    Write-Output $json
}else{
    $json | Out-File $archivo
    Write-Output "Salida guardada en $archivo"
}
