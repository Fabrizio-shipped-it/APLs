#!/bin/bash
# Script para ejecutar todos los tests de mapas en Bash

EJECUTABLE="../ejercicio2.sh"   # ruta al script principal
PRUEBAS_DIR="./"                # carpeta actual (donde están mapaX.txt)
OUT_DIR="./salidas_bash"        # carpeta para salidas

mkdir -p "$OUT_DIR"

for mapa in $PRUEBAS_DIR/mapa*.txt; do
    nombre=$(basename "$mapa" .txt)
    echo ">>> Ejecutando pruebas para $nombre"

    # Hub
    $EJECUTABLE -m "$mapa" -h
    mv "$(dirname "$mapa")/informe.$(basename "$mapa")" "$OUT_DIR/${nombre}_hub.txt"

    # Camino más corto
    $EJECUTABLE -m "$mapa" -c
    mv "$(dirname "$mapa")/informe.$(basename "$mapa")" "$OUT_DIR/${nombre}_camino.txt"
done

echo "Todas las pruebas ejecutadas. Resultados en $OUT_DIR/"
