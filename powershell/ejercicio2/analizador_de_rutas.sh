#!/usr/bin/env bash
# analizador_de_rutas.sh
# v1.0.2 — Validación de matriz corregida + hub y Dijkstra
set -Eeuo pipefail

VERSION="1.0.2"

info(){ printf "[INFO] %s\n" "$*" >&2; }
warn(){ printf "[AVISO] %s\n" "$*" >&2; }
error(){ printf "[ERROR] %s\n" "$*" >&2; }

print_help(){
cat <<'EOF'
Analizador de red de transporte (bash)

USO:
  analizador_de_rutas.sh -m ARCHIVO (-h | -c) [-s SEPARADOR]

PARÁMETROS:
  -m, --matriz    Ruta del archivo con la matriz de adyacencia (obligatorio)
  -h, --hub       Determina cuál estación es el hub (mutuamente excluyente con -c)
  -c, --camino    Calcula caminos más cortos (mutuamente excluyente con -h)
  -s, --separador Carácter separador de columnas (por defecto: | )
  -H, --help      Muestra esta ayuda
  -v, --version   Muestra versión

Salida:
  Se crea "informe.<nombreArchivoEntrada>" en el mismo directorio del archivo de entrada.
EOF
}

print_version(){ echo "analizador_de_rutas.sh v$VERSION"; }

# --- temporales ---
TMP_MTX="/tmp/analizer_mtx_$$.txt"
cleanup(){ rm -f "$TMP_MTX" 2>/dev/null || true; }
trap cleanup EXIT

# --- parámetros ---
MATRIX_FILE=""
MODE=""
SEP="|"

if [[ $# -eq 0 ]]; then print_help; exit 1; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--matriz) shift; MATRIX_FILE="${1:?Falta ruta de matriz}";;
    -h|--hub) MODE="hub";;
    -c|--camino) MODE="camino";;
    -s|--separador) shift; SEP="${1:?Falta separador}";;
    -H|--help) print_help; exit 0;;
    -v|--version) print_version; exit 0;;
    -*) error "Opción no reconocida: $1"; exit 2;;
    *) warn "Argumento ignorado: $1";;
  esac
  shift || true
done

[[ -n "$MATRIX_FILE" ]] || { error "Falta -m/--matriz"; exit 2; }
[[ -f "$MATRIX_FILE" ]] || { error "Archivo no encontrado: $MATRIX_FILE"; exit 3; }
[[ -n "$MODE" ]] || { error "Elija -h/--hub o -c/--camino"; exit 2; }

base="$(basename -- "$MATRIX_FILE")"
dir="$(dirname -- "$MATRIX_FILE")"
OUTFILE="$dir/informe.$base"

# --- Validación: cuadrada, numérica, simétrica ---
awk -v FS="$SEP" '
BEGIN{
  ok=1; rows=0; cols=-1
}
{
  rows++
  if(cols<0) cols=NF
  if(NF!=cols){
    printf "[ERROR] Fila %d tiene %d columnas; se esperaban %d.\n", rows, NF, cols > "/dev/stderr"
    ok=0
  }
  for(i=1;i<=NF;i++){
    v=$i
    gsub(/^[ \t\r]+|[ \t\r]+$/, "", v)
    if(v !~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/){
      printf "[ERROR] Valor no numérico en fila %d col %d: %s\n", rows, i, $i > "/dev/stderr"
      ok=0
    }
    m[rows,i] = v + 0
  }
}
END{
  if(!ok) exit 1
  if(rows != cols){
    printf "[ERROR] No es cuadrada: filas=%d, columnas=%d\n", rows, cols > "/dev/stderr"
    exit 1
  }
  # simetría con tolerancia
  for(i=1;i<=rows;i++){
    for(j=1;j<=cols;j++){
      d = m[i,j] - m[j,i]; if(d<0) d = -d
      if(d > 1e-9){
        printf "[ERROR] No es simétrica en (%d,%d): %g vs %g\n", i, j, m[i,j], m[j,i] > "/dev/stderr"
        exit 1
      }
    }
  }
  # salida canónica para etapas siguientes
  for(i=1;i<=rows;i++){
    line=""
    for(j=1;j<=cols;j++){
      line = line (j==1? "" : FS) m[i,j]
    }
    print line
  }
}' "$MATRIX_FILE" > "$TMP_MTX" || { error "Matriz inválida"; exit 4; }

# --- HUB ---
if [[ "$MODE" == "hub" ]]; then
  awk -v FS="$SEP" '
  {
    n=NF
    for(j=1;j<=n;j++){
      mat[NR,j] = $j + 0
    }
  }
  END{
    print "## Informe de análisis de red de transporte"
    best=-1; hub=-1
    for(i=1;i<=n;i++){
      cnt=0
      for(j=1;j<=n;j++){
        if(i!=j && mat[i,j] != 0) cnt++
      }
      if(cnt>best){best=cnt;hub=i}
    }
    if(hub==-1) {
      print "**Hub de la red:** Ninguna estación (sin conexiones)"
    } else {
      printf "**Hub de la red:** Estación %d (%d conexiones)\n", hub, best
    }
  }' "$TMP_MTX" > "$OUTFILE"
  info "Informe generado: $OUTFILE"
  exit 0
fi

# --- DIJKSTRA (todos los pares) ---
if [[ "$MODE" == "camino" ]]; then
  awk -v FS="$SEP" '
  function min_index(n,dist,vis,   i,mi,mv){
    mi=-1; mv=1e308
    for(i=1;i<=n;i++) if(!vis[i] && dist[i]<mv){ mv=dist[i]; mi=i }
    return mi
  }
  {
    n=NF
    for(j=1;j<=n;j++) mat[NR,j] = $j + 0
  }
  END{
    print "## Informe de análisis de red de transporte"
    for(src=1; src<=n; src++){
      # init
      for(i=1;i<=n;i++){ dist[i]=1e308; prev[i]=0; vis[i]=0 }
      dist[src]=0
      # dijkstra O(n^2)
      while(1){
        u=min_index(n,dist,vis); if(u<0) break
        vis[u]=1
        for(v=1; v<=n; v++){
          w=mat[u,v]
          if(w>0 && !vis[v]){
            alt=dist[u]+w
            if(alt<dist[v]){ dist[v]=alt; prev[v]=u }
          }
        }
      }
      # imprimir solo pares src<t para no duplicar
      for(t=src+1; t<=n; t++){
        if(dist[t] >= 1e308){
          printf "**Camino más corto: entre Estación %d y %d:** No conectado\n", src, t
          printf "**Tiempo total:** -\n**Ruta:** -\n\n"
          continue
        }
        # reconstrucción
        path=t; cur=t
        while(prev[cur]>0){ cur=prev[cur]; path=cur" -> "path }
        printf "**Camino más corto: entre Estación %d y %d:**\n", src, t
        printf "**Tiempo total:** %.2f minutos\n", dist[t]
        printf "**Ruta:** %s\n\n", path
      }
    }
  }' "$TMP_MTX" > "$OUTFILE"
  info "Informe generado: $OUTFILE"
  exit 0
fi

error "Modo no reconocido"; exit 2

