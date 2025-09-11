#!/bin/bash

# Archivo de salida
OUT="/tmp/lotes/stress/encuestas_2025-03-stress.txt"

mkdir -p "$(dirname "$OUT")"

> "$OUT"  # Vaciar archivo si existía

# Generar 500 encuestas
awk -v min=1 -v max=200 'BEGIN{
    srand();  # Inicializar semilla solo una vez
    for(i=1;i<=500;i++){
        # Fecha aleatoria
        dia = int(1 + rand()*31)
        hora = int(rand()*24)
        minu = int(rand()*60)
        seg = int(rand()*60)

        # Canal aleatorio
        canal = int(rand()*3)
        ch = (canal==0?"Telefono":canal==1?"Email":"Chat")

        # Tiempo de respuesta aleatorio
        tr = min + rand()*(max-min)

        # Nota de satisfacción
        ns = 1 + int(rand()*5)

        # Imprimir en formato esperado
        printf "%d|2025-03-%02d %02d:%02d:%02d|%s|%.2f|%d\n", i, dia, hora, minu, seg, ch, tr, ns
    }
}' > "$OUT"

echo "Lote de 500 encuestas generado en $OUT"

mkdir -p /tmp/lotes/loteBasico && cat > /tmp/lotes/loteBasico/2025-07-01.txt  <<'EOF'
101|2025-07-01 10:22:33|Telefono|5.5|4
102|2025-07-01 12:23:11|Email|120|5
103|2025-07-01 22:34:43|Chat|2.1|3
104|2025-06-30 23:11:10|Telefono|7.8|2
EOF
echo "Lote basico generado"

mkdir -p /tmp/lotes/fechasDiferidas && cat > /tmp/lotes/fechasDiferidas/fechasDiferidas.txt <<'EOF'
201|2025-08-01 09:12:45|Telefono|6.5|4
202|2025-08-01 11:03:12|Email|45|5
203|2025-08-01 14:45:02|Chat|3.2|2
204|2025-08-02 10:11:10|Chat|2.7|5
205|2025-08-01 23:59:59|Telefono|7.1|3
206|2025-07-31 23:58:59|Email|60|4
EOF
echo "Lote fechas diferidas generado"

mkdir -p /tmp/lotes/datosErroneos && cat > /tmp/lotes/datosErroneos/datosErroneos.txt <<'EOF'
301|2025-08-05 08:00:00|Telefono|10|5
302|2025-08-05 12:30:00|Email|abc|4
303|2025-08-05 15:45:00|Chat|5.5|
304|2025-08-05|Telefono|7.7|3
305|2025-08-05 19:20:10|Chat|3.3|2
306|2025-08-04 23:59:59|Telefono|12|1
EOF
echo "Lote datos erroneos generado"
