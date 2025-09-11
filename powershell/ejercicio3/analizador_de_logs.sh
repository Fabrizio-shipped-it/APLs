#!/bin/bash

mostrar_ayuda() {
    echo "Uso: $0 -d <directorio> -p <palabras>"
    echo
    echo "Parámetros:"
    echo "  -d, --directorio   Ruta del directorio que contiene los archivos .log"
    echo "  -p, --palabras     Lista de palabras clave separadas por comas (case sensitive)"
    echo "  -h, --help         Muestra esta ayuda"
    exit 1
}

# Validar parámetros
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directorio)
            DIRECTORIO="$2"
            shift 2
            ;;
        -p|--palabras)
            PALABRAS="$2"
            shift 2
            ;;
        -h|--help)
            mostrar_ayuda
            ;;
        *)
            echo "Parámetro desconocido: $1"
            mostrar_ayuda
            ;;
    esac
done

# Verificar parámetros obligatorios
if [[ -z "$DIRECTORIO" || -z "$PALABRAS" ]]; then
    echo "Error: faltan parámetros obligatorios."
    mostrar_ayuda
fi

# Verificar directorio
if [[ ! -d "$DIRECTORIO" ]]; then
    echo "Error: el directorio '$DIRECTORIO' no existe."
    exit 1
fi

# Convertir lista de palabras en array
IFS=',' read -r -a CLAVES <<< "$PALABRAS"

# Inicializar resumen global
declare -A GLOBAL
for palabra in "${CLAVES[@]}"; do
    GLOBAL["$palabra"]=0
done

hubo_global=false

# Procesar cada archivo .log
for archivo in "$DIRECTORIO"/*.log; do
    [[ -e "$archivo" ]] || continue

    buffer=""
    for palabra in "${CLAVES[@]}"; do
        count=$(awk -v word="$palabra" '
            {
                n = split($0, a, " ")
                for (i = 1; i <= n; i++) {
                    if (a[i] == word) {
                        c++
                    }
                }
            }
            END { print c+0 }' "$archivo")

        if (( count > 0 )); then
            buffer+="$palabra: $count"$'\n'
            GLOBAL["$palabra"]=$(( GLOBAL["$palabra"] + count ))
            hubo_global=true
        fi
    done

    # Imprimir archivo solo si tuvo coincidencias
    if [[ -n "$buffer" ]]; then
        echo "Archivo: $(basename "$archivo")"
        echo "$buffer"
    fi
done

# Resumen global (solo si hubo al menos 1 coincidencia en total)
if $hubo_global; then
    echo "===== Resumen Global ====="
    for palabra in "${CLAVES[@]}"; do
        if (( GLOBAL["$palabra"] > 0 )); then
            echo "$palabra: ${GLOBAL[$palabra]}"
        fi
    done
else 
	echo "[INFO] No se encontraron coincidencias en ningún archivo!!!"
fi

