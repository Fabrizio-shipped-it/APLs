#!/bin/bash

# MATERIA: Virtualizacion de Hardware.
# COMISION: 02 - 4900

#INTEGRANTES Grupo 6
#  VALLE,RAMIRO
#  PARRA, IGNACIO
#  CATARI EZEQUIEL MOHAMED
#  BLANCO, VICTORIA MARIEL
#  ALTAMIRANO, FABRIZIO AUGUSTO

set -euo pipefail

mostrar_ayuda() {
    echo "Parametros del script:"
    echo "  -r / --repo             Ruta del repositorio Git a monitorear. Obligatorio"
    echo "  -c / --configuracion    Ruta del archivo de configuración que contiene la lista de patrones a buscar. Obligatorio"
    echo "  -l / --log              Ruta del archivo de logs que contiene la lista de eventos identificados. Obligatorio"
    echo "  -k / --kill             Flag para detener el demonio. Solo se usa junto con -r / -repo"
    echo ""
    echo "Ejemplos:"
    echo "  ./ejercicio4.sh -r /home/user/myrepo -c ./patrones.conf -l ./patrones.log"
    echo "  ./ejercicio4.sh -r /home/user/myrepo -k"
    echo ""
}

# Comprueba dependencias
if ! command -v inotifywait >/dev/null 2>&1; then
  echo "Error: inotifywait no encontrado. Instalá inotify-tools (ej: apt install inotify-tools)." >&2
  exit 2
fi

# Verificacion de parametros
if [ "$#" -eq 0 ]; then
    echo "Error: No se han proporcionado parametros. Usa -h /--help para visualizar la ayuda."
    exit 1
fi

# Variables por defecto
kill_flag=false
WATCH_DIR=""
PATTERNS_FILE=""
LOG_FILE=""
nombre=$(basename "$WATCH_DIR")
pidfile="/tmp/demonio_${nombre}.pid"
INOTIFY_EVENTS="close_write,create,moved_to"

# Procesamiento de parametros
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -r|--repo)
            WATCH_DIR="$2"
            shift 2
            ;;
        -c|--configuracion)
            PATTERNS_FILE="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -k|--kill)
            kill_flag=true
            shift
            ;;
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo "[ERROR] Argumento invalido: '$1'"
            exit 1
            ;;
    esac
done

# Validaciones
if [[ -z "$WATCH_DIR" ]]; then
    echo "[ERROR] Debe especificar un repositorio. Usa -h /--help para visualizar la ayuda."
    exit 1
fi

# Modo kill
if $kill_flag; then
    if [[ -f "$pidfile" ]]; then
        pid=$(cat "$pidfile")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "[INFO] Matando grupo de procesos del demonio (PGID: $pid)..."
            kill -9 -$(ps -o pgid= "$pid" | grep -o '[0-9]*')
            rm "$pidfile"
            echo "[INFO] Demonio detenido para '$WATCH_DIR'."
        else
            rm "$pidfile"
        fi
    else
        echo "[ERROR] No se encontro un demonio corriendo para '$WATCH_DIR'."
    fi
    exit 0
fi


if [[ ! -f "$PATTERNS_FILE" ]]; then
    echo "[ERROR] Debe especificar un archivo de configuracion. Usa -h /--help para visualizar la ayuda."
    exit 1
fi
if [[ -z "$LOG_FILE" ]]; then
    echo "[ERROR] Debe especificar un archivo de log. Usa -h /--help para visualizar la ayuda."
    exit 1
fi

# Verificar si ya hay un demonio corriendo
if [[ -f "$pidfile" ]]; then
    pid=$(cat "$pidfile")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "[ERROR] Ya hay un demonio corriendo para '$WATCH_DIR'"
        exit 1
    else
        rm "$pidfile"
    fi
fi

declare -a PATTERNS=()

load_patterns() {
  PATTERNS=()
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    if [[ "$line" =~ ^regex: ]]; then
      p="${line#regex:}"
      p="${p#"${p%%[![:space:]]*}"}"
      p="${p%"${p##*[![:space:]]}"}"
      PATTERNS+=("R:$p")
    else
      PATTERNS+=("F:$line")
    fi
  done < "$PATTERNS_FILE"
}

log_alert() {
  local timestamp pattern file matched_line
  timestamp="$(date '+%F %T')"
  pattern="$1"
  file="$2"
  matched_line="${3:-}"
  # Formato: [2025-08-23 11:30:00] Alerta: patrón 'API_KEY' encontrado en el archivo 'config.js' (línea: ...)
  if command -v flock >/dev/null 2>&1; then
    (
      flock -n 9 || true
      if [[ -n "$matched_line" ]]; then
        printf "[%s] Alerta: patrón '%s' encontrado en el archivo '%s' — %s\n" "$timestamp" "$pattern" "$file" "$matched_line" >&9
      else
        printf "[%s] Alerta: patrón '%s' encontrado en el archivo '%s'\n" "$timestamp" "$pattern" "$file" >&9
      fi
    ) 9>>"$LOG_FILE"
  else
    if [[ -n "$matched_line" ]]; then
      printf "[%s] Alerta: patrón '%s' encontrado en el archivo '%s' — %s\n" "$timestamp" "$pattern" "$file" >> "$LOG_FILE"
    else
      printf "[%s] Alerta: patrón '%s' encontrado en el archivo '%s'\n" "$timestamp" "$pattern" "$file" >> "$LOG_FILE"
    fi
  fi
}

# Carga inicial de patrones
load_patterns

echo "Monitoreando '$WATCH_DIR' (patrones: '$PATTERNS_FILE')"
echo "Log: $LOG_FILE"
echo "Eventos escuchados: $INOTIFY_EVENTS"

# Lanzar demonio en subshell y que se ejecute en segundo plano
(
    inotifywait -m -r -e "$INOTIFY_EVENTS" --format '%w%f' "$WATCH_DIR" | while IFS= read -r filepath; do
        if [[ -d "$filepath" ]]; then
            continue
        fi

        case "$filepath" in
            *.swp|*~|*.tmp) continue ;;
        esac

        if [[ "$(realpath "$filepath")" == "$(realpath "$PATTERNS_FILE")" ]]; then
            echo "Se detectó cambio en $PATTERNS_FILE — recargando patrones..."
            load_patterns
            continue
        fi

        if [[ ! -r "$filepath" ]]; then
            continue
        fi

        # Escanear con cada patron
        for entry in "${PATTERNS[@]}"; do
            type="${entry%%:*}"
            pattern="${entry#*:}"
            if [[ "$type" == "F" ]]; then
                # busqueda literal - grep -F
                if grep -F --line-number -- "$pattern" "$filepath" >/dev/null 2>&1; then
                    first="$(grep -F --line-number --max-count=1 -- "$pattern" "$filepath" | sed 's/^[0-9]\+://')"
                    log_alert "$pattern" "$filepath" "$first"
                fi
            else
                if grep -E --line-number -- "$pattern" "$filepath" >/dev/null 2>&1; then
                    first="$(grep -E --line-number --max-count=1 -- "$pattern" "$filepath" | sed 's/^[0-9]\+://')"
                    log_alert "regex:$pattern" "$filepath" "$first"
                fi
            fi
        done
    done
) >> "$LOG_FILE" 2>&1 &

# Guardar PID del subshell principal y desvincular
echo $! > "$pidfile"
disown
