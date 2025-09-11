#!/usr/bin/env bash
# audit.sh
# Demonio para auditar repositorios git en busca de patrones/credenciales
# Uso: ./audit.sh -r /ruta/al/repo -c /ruta/patrones.conf -l /ruta/a/log -i 10
# Parar: ./audit.sh -r /ruta/al/repo -k

set -Eeuo pipefail
VERSION="1.0.0"

info(){ printf "[INFO] %s\n" "$*" >&2; }
warn(){ printf "[AVISO] %s\n" "$*" >&2; }
error(){ printf "[ERROR] %s\n" "$*" >&2; }

print_help(){
  cat <<'EOF'
audit.sh - Demonio de auditoría de repositorios Git (Local)

USO:
  Iniciar:
    ./analizador_de_repos.sh -r /ruta/al/repo -c /ruta/patrones.conf -l /ruta/a/log -i 10 -b main

  Detener:
    ./analizador_de_repos.sh -r /ruta/al/repo -k

Parámetros:
  -r, --repo           Ruta del repositorio Git a monitorear (obligatorio).
  -c, --configuracion  Archivo con patrones (una línea por patrón). Prefijo 'regex:' para regex.
  -l, --log            Archivo de log donde se escriben las alertas. (default: <repo>/audit.log)
  -i, --interval       Intervalo de polling en segundos (default: 10).
  -b, --branch         Rama objetivo (default: main).
  -k, --kill           Detener el demonio asociado al repo.
  -h, --help           Muestra esta ayuda.
  -v, --version        Muestra versión.
EOF
}

# ---- Parseo de parámetros ----
REPO=""
CONFIG=""
LOGFILE=""
INTERVAL=10
TARGET_BRANCH="main"
DO_KILL=false

if [[ $# -eq 0 ]]; then print_help; exit 1; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repo) shift; REPO="$1";;
    -c|--configuracion) shift; CONFIG="$1";;
    -l|--log) shift; LOGFILE="$1";;
    -i|--interval) shift; INTERVAL="$1";;
    -b|--branch) shift; TARGET_BRANCH="$1";;
    -k|--kill) DO_KILL=true;;
    -h|--help) print_help; exit 0;;
    -v|--version) echo "audit.sh v$VERSION"; exit 0;;
    *) error "Opción no reconocida: $1"; print_help; exit 2;;
  esac
  shift || true
done

# ---- Validaciones básicas ----
[[ -n "$REPO" ]] || { error "Falta -r/--repo"; exit 2; }
REPO=$(realpath -s "$REPO") || REPO="$REPO"
if [[ ! -d "$REPO" ]]; then error "Repositorio no encontrado: $REPO"; exit 3; fi

# El log por defecto
if [[ -z "$LOGFILE" ]]; then
  LOGFILE="$REPO/audit.log"
fi

# Elegir hash tool para crear nombre único
if command -v sha256sum >/dev/null 2>&1; then
  HASHCMD="sha256sum"
elif command -v md5sum >/dev/null 2>&1; then
  HASHCMD="md5sum"
else
  HASHCMD="cat"  # degradado (poco ideal)
fi
REPO_HASH=$({ printf "%s" "$REPO" | $HASHCMD; } | awk '{print $1}' )
PIDFILE="/tmp/audit_${REPO_HASH}.pid"
TMP_RUN="/tmp/audit_run_${REPO_HASH}.sh"

# ---- Modo kill: detener demonio existente para este repo ----
if $DO_KILL; then
  if [[ ! -f "$PIDFILE" ]]; then error "No se encontró demonio en ejecución para $REPO (no existe $PIDFILE)"; exit 4; fi
  read -r PID < "$PIDFILE"
  read -r PID_REPO < <(sed -n '2p' "$PIDFILE" 2>/dev/null || printf "")
  # validar coincide con repo
  if [[ "$PID_REPO" != "$REPO" ]]; then
    warn "El pidfile $PIDFILE no corresponde a este repo (pidfile repo: $PID_REPO)"; exit 5
  fi
  if kill -0 "$PID" >/dev/null 2>&1; then
    info "Enviando SIGTERM al demonio (PID $PID)..."
    kill "$PID"
    # esperar hasta que cierre
    for i in $(seq 1 20); do
      if ! kill -0 "$PID" >/dev/null 2>&1; then break; fi
      sleep 0.5
    done
    if kill -0 "$PID" >/dev/null 2>&1; then
      warn "El proceso no terminó tras SIGTERM, enviando SIGKILL..."
      kill -9 "$PID" || true
    fi
    rm -f "$PIDFILE" "$TMP_RUN" 2>/dev/null || true
    info "Demonio detenido."
    exit 0
  else
    warn "Proceso $PID no existe. Eliminando pidfile stale."
    rm -f "$PIDFILE" "$TMP_RUN" 2>/dev/null || true
    exit 0
  fi
fi

# ---- Iniciar demonio: validaciones adicionales ----
if [[ -f "$PIDFILE" ]]; then
  read -r OLDPID < "$PIDFILE" 2>/dev/null || OLDPID=""
  read -r OLDREPO < <(sed -n '2p' "$PIDFILE" 2>/dev/null || printf "")
  if [[ -n "$OLDPID" && -n "$OLDREPO" && "$OLDREPO" == "$REPO" && kill -0 "$OLDPID" >/dev/null 2>&1 ]]; then
    error "Ya hay un demonio en ejecución para este repositorio (PID $OLDPID). Detenerlo antes con -k."
    exit 6
  else
    warn "Pidfile stale detectado. Lo borro."
    rm -f "$PIDFILE" "$TMP_RUN" 2>/dev/null || true
  fi
fi

if [[ -z "$CONFIG" || ! -f "$CONFIG" ]]; then
  error "Archivo de configuración de patrones inválido o faltante (-c)."; exit 7
fi

if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "La ruta no parece un repositorio Git: $REPO"; exit 8
fi

# Asegurar directorio de log
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE" || { error "No puedo escribir en $LOGFILE"; exit 9; }

# ---- Crear script de ejecución en background (runner) ----
# Escribimos unas variables (expandidas ahora) y luego el cuerpo literal que usará esas variables.
cat > "$TMP_RUN" <<EOF
#!/usr/bin/env bash
# Runner temporal para audit daemon
REPO='${REPO}'
CONFIG='${CONFIG}'
LOGFILE='${LOGFILE}'
INTERVAL=${INTERVAL}
TARGET_BRANCH='${TARGET_BRANCH}'
PIDFILE='${PIDFILE}'
TMP_RUN='${TMP_RUN}'

cleanup(){
  # eliminar pidfile y este script al terminar
  [[ -f "\$PIDFILE" ]] && rm -f "\$PIDFILE" || true
  [[ -f "\$TMP_RUN" ]] && rm -f "\$TMP_RUN" || true
}
trap 'cleanup; exit' SIGTERM SIGINT EXIT

cd "\$REPO" || exit 1

# cargar patrones en array (ignorar comentarios y líneas vacías)
patterns=()
while IFS= read -r line || [[ -n "\$line" ]]; do
  # trim
  trimmed=\$(echo "\$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*\$//' )
  [[ -z "\$trimmed" ]] && continue
  [[ "\$trimmed" =~ ^# ]] && continue
  patterns+=( "\$trimmed" )
done < "\$CONFIG"

last_commit="NONE"
if git rev-parse HEAD >/dev/null 2>&1; then
  last_commit=\$(git rev-parse HEAD 2>/dev/null || echo "NONE")
fi

# Loop principal
while true; do
  # verificar rama actual
  branch=\$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "\$branch" != "\$TARGET_BRANCH" ]]; then
    # no estamos en la rama objetivo; esperar y continuar
    sleep "\$INTERVAL"
    continue
  fi

  current=\$(git rev-parse HEAD 2>/dev/null || echo "")
  if [[ "\$current" != "\$last_commit" ]]; then
    # obtener archivos modificados entre commits
    if [[ "\$last_commit" == "NONE" ]]; then
      modified_files=\$(git ls-files)
    else
      modified_files=\$(git diff --name-only "\$last_commit" "\$current")
    fi

    # recorrer archivos modificados
    IFS=$'\\n'
    for f in \$modified_files; do
      [[ -z "\$f" ]] && continue
      # path absoluto al archivo en repo
      filepath="\$REPO/\$f"
      if [[ ! -f "\$filepath" ]]; then
        # puede ser archivo borrado; ignorar
        continue
      fi

      # para cada patrón, buscar coincidencias
      for pat in "\${patterns[@]}"; do
        if [[ "\$pat" == regex:* ]]; then
          regex="\${pat#regex:}"
          # usar grep -En (extended regex, número de línea)
          matches=\$(grep -En -- "\$regex" "\$filepath" 2>/dev/null || true)
        else
          # literal search
          matches=\$(grep -Fn -- "\$pat" "\$filepath" 2>/dev/null || true)
        fi

        if [[ -n "\$matches" ]]; then
          # por cada línea coincidente, escribir alerta en log con timestamp
          while IFS= read -r mline; do
            ts=\$(date '+%Y-%m-%d %H:%M:%S')
            # mline contiene "num:linecontent" (si hay : en el texto, grep -n usa la primer :)
            echo "[\$ts] Alerta: patrón '\$pat' encontrado en el archivo '\$f' -> \$mline" >> "\$LOGFILE"
          done <<< "\$matches"
        fi
      done
    done
    unset IFS

    last_commit="\$current"
  fi

  sleep "\$INTERVAL"
done
EOF

chmod +x "$TMP_RUN"

# ---- Lanzar en background usando nohup/setsid para liberar terminal ----
nohup bash "$TMP_RUN" >/dev/null 2>&1 &
PID=$!
# escribir pidfile: primera línea PID, segunda línea repo
printf "%s\n%s\n" "$PID" "$REPO" > "$PIDFILE"
info "Demonio iniciado (PID $PID). Ver logs en $LOGFILE"
exit 0

