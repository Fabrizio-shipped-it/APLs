#!/usr/bin/env bash
# Analizador de encuestas de satisfacción
# Lee archivos con formato: ID|FECHA(yyyy-mm-dd hh:mm:ss)|CANAL|TIEMPO(min)|NOTA(1-5)
# Recorre todos los archivos de un directorio, calcula promedios por DÍA y por CANAL, y emite JSON
# Requisitos: bash, jq, awk,  coreutils

set -Euo pipefail	#-E corta si hay error|-u Error si hay variables no definidas
			#-o pipefail si un comando en un pipe falla, falla todo
VERSION="1.0.0"		#Variable (version)

# ===== Mensajes =====
info()  { printf "[INFO] %s\n"  "$*" >&2; } #Mensajes claros para el usuario, van a stderr para no mezclarse
warn()  { printf "[AVISO] %s\n" "$*" >&2; } #con la salida del JSON
error() { printf "[ERROR] %s\n" "$*" >&2; }

# ===== Ayuda ===== Muestra un mensaje completo de ayuda con -h
print_help() {
  cat <<'EOF'
Analizador de encuestas de satisfacción (Bash)

USO:
  analizador_de_encuestas.sh -d DIR (-p | -a SALIDA.json)

PARÁMETROS:
  -d, --directorio   Ruta del directorio con archivos a procesar (requerido)
  -p, --pantalla     Muestra la salida JSON por pantalla (mutuamente excluyente con -a)
  -a, --archivo      Ruta del archivo de salida JSON (mutuamente excluyente con -p)
  -h, --help         Muestra esta ayuda y sale
  -v, --version      Muestra la versión y sale

NOTAS:
  * Se aceptan rutas relativas o absolutas, con espacios.
  * Se procesan TODOS los archivos TXT dentro del directorio indicado (independiente del nombre).
  * Las fechas se toman del propio campo FECHA del registro, no del nombre del archivo.
  * Líneas mal formateadas se ignoran con aviso. Se valida que TIEMPO sea numérico y NOTA ∈ [1..5].
  * Requiere 'jq' para construir JSON. Instalar: sudo apt-get install jq (o equivalente).
  * Archivos temporales se crean en /tmp y se eliminan automáticamente.
EOF
}

print_version() { echo "analizador_de_encuestas.sh v$VERSION"; } #Muestra la version del script

# ===== Limpieza segura =====
TMP1="/tmp/enc_tmp_$$.tsv"     # líneas válidas normalizadas
TMP2="/tmp/enc_agg_$$.tsv"     # agregados por (fecha, canal)
OUTTMP="/tmp/enc_json_$$.json" # JSON final temporal

cleanup() {
  rm -f -- "$TMP1" "$TMP2" "$OUTTMP" 2>/dev/null || true
} #Remueve todo una vez finalizado.

on_error() {
  local ec=$?
  error "Ocurrió un problema inesperado. Se detuvo el proceso para evitar resultados inválidos. Código: $ec"
  exit $ec
} #En caso de error, muestra un mensaje

trap cleanup EXIT #Ejecua funcion cleanup para limpieza una vez terminado el script (bien o mal)
trap on_error ERR #En caso de error, ejecuta funcion

# ===== Parseo de parámetros (cualquier orden, cortos/largos) =====
DIR=""
TO_STDOUT=false
OUTFILE=""

				#Si no ingreso ninguna variable, muestro mensaje de ayuda
if [[ $# -eq 0 ]];then
  print_help; exit 1
fi
				#Aca parseamos las variables recibidas e informamos en caso de que falte alguna
				#O en caso de que se ingrese una opcion invalida
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--directorio)
      shift; [[ $# -gt 0 ]] || { error "Falta valor para -d/--directorio"; exit 2; }
      DIR="$1";
      ;;
    -p|--pantalla)
      TO_STDOUT=true;
      ;;
    -a|--archivo)
      shift; [[ $# -gt 0 ]] || { error "Falta ruta para -a/--archivo"; exit 2; }
      OUTFILE="$1";
      ;;
    -h|--help)
      print_help; exit 0;
      ;;
    -v|--version)
      print_version; exit 0;
      ;;
    --) shift; break;;
    -*) error "Opción no reconocida: $1"; print_help; exit 2;;
    *)  # argumento suelto (no se espera en este script)
      warn "Argumento ignorado: $1";
      ;;
  esac
  shift || true
done



# Validaciones pedidas segun enunciado.  No combinar -a con -p

[[ -n "$DIR" ]] || { error "Debe indicar -d/--directorio"; exit 2; }
[[ -d "$DIR" ]] || { error "El directorio no existe o no es accesible: $DIR"; exit 2; }

if $TO_STDOUT && [[ -n "$OUTFILE" ]]; then
  error "-p/--pantalla y -a/--archivo no pueden usarse juntos"; exit 2
fi
if ! $TO_STDOUT && [[ -z "$OUTFILE" ]]; then
  error "Debe elegir una salida: -p/--pantalla o -a/--archivo"; exit 2
fi



# Verificar la existencia de jq en el sistema (Que se haya instalado)
if ! command -v jq >/dev/null 2>&1; then
  error "No se encontró 'jq'. Instale jq para generar la salida JSON."; exit 3
fi

# ===== Normalización y validación de líneas =====
# Salida TSV con columnas: FECHA(YYYY-MM-DD) \t CANAL \t TIEMPO \t NOTA \t 1
: > "$TMP1"
shopt -s nullglob

# Recorremos archivos regulares de primer nivel, soportando espacios en nombres
found_any=false
while IFS= read -r -d '' f; do
  found_any=true
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Saltar vacías
    [[ -n "${line//[[:space:]]/}" ]] || continue

    IFS='|' read -r id fecha canal tiempo nota <<<"$line"

    # Validaciones de que esten todos los campos enunciados, ni mas ni menos.
    # 5 campos presentes
    if [[ -z "${id:-}" || -z "${fecha:-}" || -z "${canal:-}" || -z "${tiempo:-}" || -z "${nota:-}" ]]; then
      warn "Línea inválida (faltan campos) en '$f': $line"; continue
    fi

    # id numérico (entero)
    if ! [[ $id =~ ^[0-9]+$ ]]; then
      warn "ID no numérico, se omite: $line"; continue
    fi

    # fecha formato YYYY-MM-DD HH:MM:SS -> nos quedamos con la fecha
    if [[ $fecha =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
      dia="${BASH_REMATCH[1]}"
    else
      warn "Fecha inválida, se omite: $line"; continue
    fi

    # tiempo numérico (permite decimales con punto)
    if ! [[ $tiempo =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      warn "Tiempo de respuesta inválido, se omite: $line"; continue
    fi

    # nota 1..5 (entero)
    if ! [[ $nota =~ ^[1-5]$ ]]; then
      warn "Nota de satisfacción inválida, se omite: $line"; continue
    fi

    printf "%s\t%s\t%s\t%s\t1\n" "$dia" "$canal" "$tiempo" "$nota" >> "$TMP1"
  done < "$f"

done < <(find "$DIR" -mindepth 1 -maxdepth 1 -type f -name '*.txt' -print0)


if ! $found_any; then	#En caso de que no haya archivos en el directorio pasado como parametro
  error "No se encontraron archivos para procesar en: $DIR"; exit 4
fi

if [[ ! -s "$TMP1" ]]; then #En caso de que archivos esten mal generados
  warn "No hubo líneas válidas tras la validación. Se generará JSON vacío."
  echo '{}' > "$OUTTMP"
else					      ######################
  # ===== Agregación por (fecha, canal) =====## Bendito sea el awk ##
  awk -F '\t' '	#Awk entiende que los campos estan separados por tabulaciones
    { 	key=$1"|"$2; ##La key queda como año-mes-dia|Canal de comunicacion
	sumt[key]+=$3; ##Acumula tiempos por ESE grupo (fecha|canal)
	sumn[key]+=$4; ##Acumula notas de satisfaccion por (fecha|canal)
	c[key]+=$5     ##Cuena cuanta cantidad de registros hay por (fecha|canal)
    }	#Los $1,2,3,4,5 son los campos fecha, canal, tiempo, nota, un contador
    END {
	   PROCINFO["sorted_in"]="@ind_str_asc" #Aca ordeno claves alfabeticamente, siendo primero por FECHA
      for (k in c) 
	{
	        split(k, a, "|")
        	trp = sumt[k]/c[k] ##Promedio de tiempo de respuesta
	        nsp = sumn[k]/c[k] ##Promedio de nota de satisfaccion
	        # Imprimimos salida TABULADA como: fecha \t canal \t prom_tiempo \t prom_nota
       		 printf "%s\t%s\t%.1f\t%.1f\n", a[1], a[2], trp, nsp
        }
    }
  ' "$TMP1" > "$TMP2"





  # ===== Construcción de JSON con jq =====
  # Estructura final: { "YYYY-MM-DD": { "Canal": {"tiempo_respuesta_promedio": x, "nota_satisfaccion_promedio": y }, ... }, ... }
  jq -R -s '
    split("\n")
    | map(select(length>0))
    | map(split("\t"))
    | map({date: .[0], channel: .[1], trp: (.[2]|tonumber), nsp: (.[3]|tonumber)})
    | group_by(.date)
    | map({ (.[0].date): ( map({ ( .channel ): { tiempo_respuesta_promedio: .trp, nota_satisfaccion_promedio: .nsp } }) | add ) })
    | add // {} 
  ' "$TMP2" > "$OUTTMP"
fi




# ===== Salida =====
if $TO_STDOUT; then	#Aca va a depender si ingresamos al inicio -p
  cat "$OUTTMP"
else			#O si ingresamos -a con directorio para dejar el JSON
  # Crear directorio de salida si no existe
  outdir=$(dirname -- "$OUTFILE")
  mkdir -p -- "$outdir"
  cp -- "$OUTTMP" "$OUTFILE"
  info "JSON generado en: $OUTFILE"
fi

exit 0
