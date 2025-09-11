#!/usr/bin/env bash
# buscador_paises.sh
# Buscador de información de países usando la API REST Countries v3.1
# - Soporta cache por país con TTL
# - Guarda cache persistente en $XDG_CACHE_HOME/buscador_paises (o ~/.cache/...)
# - Requiere: curl, jq
#
# Uso:
#   ./buscador_paises.sh -n "Spain,Argentina" -t 3600
#   ./buscador_paises.sh -n "United States"  # usa TTL por defecto
#
set -Eeuo pipefail
VERSION="1.0.0"

print_help(){
  cat <<'EOF'
Buscador de países (bash)

USO:
  buscador_paises.sh -n "pais1,pais2,..." [-t TTL]

PARAMETROS:
  -n, --nombre    Nombre(s) de país. Puede usarse una cadena con comas o repetir la opción.
  -t, --ttl       TTL en segundos (opcional). Por defecto 86400 (1 día).
  -h, --help      Muestra esta ayuda.
  -v, --version   Muestra versión.

Ejemplo:
  ./buscador_paises.sh -n "Spain,United States" -t 3600

Este script consultará la API https://restcountries.com/v3.1/name/{nombre}
Los resultados se guardan en caché en:
  $XDG_CACHE_HOME/buscador_paises (o ~/.cache/buscador_paises)

EOF
}

# ---- Parámetros por defecto ----
TTL_DEFAULT=86400  # 1 día
TTL="$TTL_DEFAULT"

# ---- Dependencias ----
for dep in curl jq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    printf "[ERROR] Falta dependencia: %s. Instale antes de ejecutar.\n" "$dep" >&2
    exit 1
  fi
done

# ---- Parseo de parámetros ----
NAMES=()
if [[ $# -eq 0 ]]; then
  print_help; exit 1
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--nombre)
      shift; [[ $# -gt 0 ]] || { printf "[ERROR] Falta valor para -n/--nombre\n" >&2; exit 2; }
      # soportar tanto coma-separado como repetido
      IFS=',' read -r -a parts <<< "$1"
      for p in "${parts[@]}"; do
        # trim
        p_trimmed=$(echo "$p" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        [[ -n "$p_trimmed" ]] && NAMES+=("$p_trimmed")
      done
      ;;
    -t|--ttl)
      shift; [[ $# -gt 0 ]] || { printf "[ERROR] Falta valor para -t/--ttl\n" >&2; exit 2; }
      TTL="$1";
      if ! [[ "$TTL" =~ ^[0-9]+$ ]]; then
        printf "[ERROR] TTL debe ser un entero (segundos)\n" >&2; exit 2
      fi
      ;;
    -h|--help)
      print_help; exit 0;;
    -v|--version)
      printf "%s v%s\n" "$(basename "$0")" "$VERSION"; exit 0;;
    -*) printf "[ERROR] Opcion desconocida: %s\n" "$1" >&2; print_help; exit 2;;
    *) # permitir nombres sueltos sin flag
      p_trimmed=$(echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      [[ -n "$p_trimmed" ]] && NAMES+=("$p_trimmed")
      ;;
  esac
  shift || true
done

if [[ ${#NAMES[@]} -eq 0 ]]; then
  printf "[ERROR] Debe indicar al menos un nombre de país con -n\n" >&2; exit 2
fi

# ---- Cache dir ----
CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}"
CACHE_DIR="$CACHE_BASE/buscador_paises"
mkdir -p "$CACHE_DIR"

# ---- Temp dir (en /tmp) y limpieza ----
TMPDIR=$(mktemp -d "/tmp/buscador_paises.XXXXXX")
trap 'rm -rf "$TMPDIR"' EXIT

# ---- Helpers ----
# function: normalize name to cache key (lower, replace non-alnum by _)
normalize_key(){
  local s="$1"
  printf "%s" "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+|_+$//g'
}

# function: pretty print a response JSON file (may contain array)
print_country_info(){
  local respfile="$1"
  # For each element in the array, print desired fields
  jq -r '
    .[] |
    ( ( .name.common // .name.official ) ) as $country |
    ("Pa\u00eds: " + $country),
    ("Capital: " + ((.capital[0]) // "N/A")),
    ("Regi\u00f3n: " + (.region // "N/A")),
    ("Poblaci\u00f3n: " + ((.population|tostring) // "N/A")),
    ("Moneda: " + (if .currencies then (.currencies | to_entries | map(.value.name + " (" + .key + ")") | join(", ")) else "N/A" end)),
    ""
  ' "$respfile"
}

# ---- Main loop: por cada nombre ----
for name in "${NAMES[@]}"; do
  printf "==> Buscando: %s\n" "$name"
  key=$(normalize_key "$name")
  cache_file="$CACHE_DIR/$key.json"
  now=$(date +%s)
  use_cache=false
  if [[ -f "$cache_file" ]]; then
    fetched_at=$(jq -r '.fetched_at // 0' "$cache_file")
    age=$(( now - fetched_at ))
    if (( age < TTL )); then
      use_cache=true
      jq -c '.response' "$cache_file" > "$TMPDIR/resp_${key}.json"
      printf "(Usando cache, %d segundos desde la última consulta)\n" "$age"
    fi
  fi

  if ! $use_cache; then
    # preparar URL (reemplazo simple de espacios)
    encoded=${name// /%20}
    url="https://restcountries.com/v3.1/name/$encoded"
    resp_tmp="$TMPDIR/resp_fetch_${key}.json"

    http_code=$(curl -sS -w "%{http_code}" -o "$resp_tmp" "$url") || {
      printf "[ERROR] Fallo la consulta HTTP para '%s'\n" "$name" >&2; continue
    }

    if [[ "$http_code" -ge 400 ]]; then
      # Puede ser 404 Not Found
      printf "[AVISO] No se encontraron resultados para '%s' (HTTP %s)\n" "$name" "$http_code" >&2
      continue
    fi

    # validar que la respuesta sea un array con al menos 1 elemento
    if ! jq -e 'if type=="array" and length>0 then . else empty end' "$resp_tmp" >/dev/null 2>&1; then
      printf "[AVISO] Respuesta inesperada para '%s' (no es array)\n" "$name" >&2
      continue
    fi

    # Guardar en cache (fetched_at + response)
    fetched_at=$(date +%s)
    cache_tmp="$TMPDIR/cache_${key}.json"
    printf '{"fetched_at":%s,"response":' "$fetched_at" > "$cache_tmp"
    cat "$resp_tmp" >> "$cache_tmp"
    printf '}' >> "$cache_tmp"
    mv -f "$cache_tmp" "$cache_file"
    mv -f "$resp_tmp" "$TMPDIR/resp_${key}.json"
    printf "(Guardado en cache)\n"
  fi

  # Imprimir info usando jq
  print_country_info "$TMPDIR/resp_${key}.json"
done

exit 0

