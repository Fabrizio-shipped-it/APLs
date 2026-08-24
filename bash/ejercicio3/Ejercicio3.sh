#!/bin/bash
# ejercicio3.sh

#INTEGRANTES Grupo 6
#  VALLE,RAMIRO
#  PARRA, IGNACIO
#  CATARI EZEQUIEL MOHAMED
#  BLANCO, VICTORIA MARIEL
#  ALTAMIRANO, FABRIZIO AUGUSTO

# Objetivo: contar ocurrencias de palabras clave en archivos .log usando AWK
set -euo pipefail

# variables
tmpfile=""
directorio=""
palabras=""

# limpieza al salir (exitoso o por error)
cleanup() {
    # si tmpfile existe, lo borramos
    if [[ -n "${tmpfile:-}" && -f "$tmpfile" ]]; then
        rm -f "$tmpfile"
    fi
}
trap 'cleanup' EXIT
trap 'echo "Ocurrió un error inesperado. Saliendo..."; cleanup; exit 1' ERR

mostrar_ayuda() {
    cat <<EOF
Uso: $0 -d <directorio_logs> -p <palabras>
  -d, --directorio   Ruta del directorio con archivos .log
  -p, --palabras     Lista de palabras clave separadas por comas (ej: "usb,invalid")
  -h, --help         Muestra esta ayuda
EOF
}

# parseo de parámetros (cualquier orden)
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            mostrar_ayuda
            exit 0
            ;;
        -d|--directorio)
            directorio="$2"
            shift 2
            ;;
        -p|--palabras)
            palabras="$2"
            shift 2
            ;;
        *)
            echo "Parámetro desconocido: $1" >&2
            mostrar_ayuda
            exit 1
            ;;
    esac
done

# validación parámetros obligatorios
if [[ -z "$directorio" || -z "$palabras" ]]; then
    echo "Error: faltan parámetros obligatorios." >&2
    mostrar_ayuda
    exit 1
fi

# validar directorio
if [[ ! -d "$directorio" ]]; then
    echo "Error: el directorio '$directorio' no existe o no es un directorio accesible." >&2
    exit 1
fi

# normalizar lista de palabras: quitar espacios alrededor de comas
palabras="${palabras//, /,}"
palabras="${palabras// ,/,}"
# quitar posibles comas iniciales/finales
palabras="${palabras#,}"
palabras="${palabras%,}"

# buscar archivos .log en el directorio (no recursivo)
shopt -s nullglob
logs=("$directorio"/*.log)
shopt -u nullglob

if (( ${#logs[@]} == 0 )); then
    echo "No se encontraron archivos .log en '$directorio'." >&2
    exit 1
fi

# crear archivo temporal en /tmp y concatenar logs allí
tmpfile=$(mktemp /tmp/ej3_logs_XXXXXX) || { echo "No se pudo crear archivo temporal en /tmp" >&2; exit 1; }
for f in "${logs[@]}"; do
    if [[ -r "$f" ]]; then
        cat -- "$f" >> "$tmpfile"
    else
        echo "Advertencia: no se puede leer '$f', se omite." >&2
    fi
done

# Usamos AWK para contar (case-insensitive, cuenta múltiples apariciones)
awk -v kws="$palabras" '
BEGIN{
    # separar keywords por coma y guardarlas en arrays keys[1..n]
    n = split(kws, a, ",")
    for (i=1; i<=n; i++) {
        # trim de espacios
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        keys[i] = a[i]
        low[a[i]] = tolower(a[i])
        counts[low[a[i]]] = 0
    }
}
{
    line = tolower($0)
    for (i=1; i<=n; i++) {
        k = low[keys[i]]
        # gsub devuelve la cantidad de reemplazos -> número de ocurrencias
        matches = gsub(k, "&", line)
        counts[k] += matches
    }
}
END{
    for (i=1; i<=n; i++) {
        k_orig = keys[i]
        k_low = low[k_orig]
        printf "%s: %d\n", k_orig, counts[k_low] + 0
    }
}
' "$tmpfile"

# cleanup se hará por el trap EXIT
exit 0
