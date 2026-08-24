#!/bin/bash
# Ejercicio 2 - Análisis de rutas en un mapa de transporte

#INTEGRANTES Grupo 6
#  VALLE,RAMIRO
#  PARRA, IGNACIO
#  CATARI EZEQUIEL MOHAMED
#  BLANCO, VICTORIA MARIEL
#  ALTAMIRANO, FABRIZIO AUGUSTO


mostrar_ayuda() {
    echo "Uso: $0 -m <archivo_matriz> [-h | -c] [-s <separador>]"
    echo "  -m, --matriz       Ruta del archivo de matriz"
    echo "  -h, --hub          Determinar estación con más conexiones"
    echo "  -c, --camino       Encontrar camino más corto (Dijkstra)"
    echo "  -s, --separador    Separador de columnas (default='|')"
    exit 1
}

# --- Parseo de parámetros ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--matriz) MATRIZ="$2"; shift 2;;
    -h|--hub) HUB=1; shift;;
    -c|--camino) CAMINO=1; shift;;
    -s|--separador) SEP="$2"; shift 2;;
    -help|-ayuda) mostrar_ayuda;;
    *) echo "Parámetro desconocido: $1"; mostrar_ayuda;;
  esac
done

SEP=${SEP:-"|"} # separador por defecto

if [[ -z "$MATRIZ" ]]; then
    echo "Error: Debe especificar un archivo de matriz"
    exit 1
fi

if [[ $HUB && $CAMINO ]]; then
    echo "Error: no se puede usar -h/--hub y -c/--camino al mismo tiempo"
    exit 1
fi

OUTFILE="$(dirname "$MATRIZ")/informe.$(basename "$MATRIZ")"

# --- Leer matriz ---
mapfile -t LINES < "$MATRIZ"
N=${#LINES[@]}
declare -A GRAFO

for ((i=0; i<N; i++)); do
    row=($(echo "${LINES[i]}" | tr "$SEP" ' '))
    if [[ ${#row[@]} -ne $N ]]; then
        echo "Error: la matriz no es cuadrada"
        exit 1
    fi
    for ((j=0; j<N; j++)); do
        GRAFO[$i,$j]=${row[j]}
    done
done

# --- Hub ---
if [[ $HUB ]]; then
max=0; hub_est=()
for ((i=0; i<N; i++)); do
    count=0
    for ((j=0; j<N; j++)); do
        [[ ${GRAFO[$i,$j]} != "0" ]] && ((count++))
    done
    if (( count > max )); then
        max=$count
        hub_est=($((i+1)))
    elif (( count == max )); then
        hub_est+=($((i+1)))
    fi
done
    echo -e "## Informe de análisis de red de transporte\n**Hub de la red:** Estaciones ${hub_est[*]} ($max conexiones)" > "$OUTFILE"
    exit 0
fi

# --- Dijkstra ---
if [[ $CAMINO ]]; then
    # Por simplicidad: ruta entre estación 1 y estación N
    origen=0
    destino=$((N-1))

    declare -a dist prev visited
    for ((i=0; i<N; i++)); do
        dist[$i]=999999
        prev[$i]=-1
        visited[$i]=0
    done
    dist[$origen]=0

    for ((k=0; k<N; k++)); do
        # buscar no visitado con menor dist
        u=-1; min=999999
        for ((i=0; i<N; i++)); do
            if (( visited[i]==0 && dist[i]<min )); then
                min=${dist[i]}; u=$i
            fi
        done
        (( u==-1 )) && break
        visited[$u]=1

        for ((v=0; v<N; v++)); do
            peso=${GRAFO[$u,$v]}
            [[ $peso == "0" ]] && continue
            if (( dist[u] + ${peso%.*} < dist[v] )); then
                dist[v]=$((dist[u]+${peso%.*}))
                prev[v]=$u
            fi
        done
    done

    # reconstruir ruta
    ruta=()
    nodo=$destino
    while (( nodo!=-1 )); do
        ruta=($((nodo+1)) "${ruta[@]}")
        nodo=${prev[$nodo]}
    done
    ruta_str=$(printf " -> %s" "${ruta[@]}")
ruta_str=${ruta_str:4} 
echo -e "## Informe de análisis de red de transporte\n**Camino más corto: entre Estación 1 y Estación $N:**\n**Tiempo total:** ${dist[$destino]} minutos\n**Ruta:** $ruta_str" > "$OUTFILE"
    exit 0
fi
