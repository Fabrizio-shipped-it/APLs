#!/bin/bash

#INTEGRANTES Grupo 6
#  VALLE,RAMIRO
#  PARRA, IGNACIO
#  CATARI EZEQUIEL MOHAMED
#  BLANCO, VICTORIA MARIEL
#  ALTAMIRANO, FABRIZIO AUGUSTO

function ayuda() {
    cat << EOF
    Uso: $(basename "$0") 

    Analizar resultados de encuestas de satisfacción de clientses.
    Procesa archivos de texto tabulados (campos separados por '|'),
    calcula promedios de tiempo de respuesta y de nota de satisfacción
    agrupados por canal de atención y por día.

    Parámetros obligatorios:
    -d, --directorio DIR   Ruta del directorio que contiene los archivos de encuestas(absoluta o relativa).

    Parámetros de salida (excluyentes):
    -a, --archivo FILE     Ruta del archivo JSON de salida.
    -p, --pantalla         Muestra la salida en pantalla en formato JSON.

    Opciones adicionales:
    -h, --help             Muestra esta ayuda y termina.

    Formato de los archivos de entrada:
    Cada archivo contiene encuestas en líneas con el siguiente formato:
        ID_ENCUESTA|FECHA|CANAL|TIEMPO_RESPUESTA|NOTA_SATISFACCION

    Ejemplo de uso:
    $(basename "$0") -d ./lote -p
    $(basename "$0") -d ./lote -a resultados.json
EOF
}

function opciones_parametros() {
    options=$(getopt -o d:a:ph --long help,directorio:,archivo:,pantalla -- "$@")
    #p va sin el ':' porque no tiene argumento, es solo el indicador de que sale por pantallla
    if [ "$?" != "0" ]
    then
        echo 'Opciones incorrectas. Use -h para ver ayuda.'
        exit 1
    fi
    eval set -- "$options"
    while true
    do
        case "$1" in  
            -d | --directorio) 
                directorio="$2"
                shift 2
                ;;
            -a | --archivo)
                archivo="$2"
                shift 2
                ;;
            -p | --pantalla)
                pantalla=1
                shift
                ;;
            -h | --help)
                ayuda
                exit 0
                ;;
            --) # case "--":
                shift
                break
                ;;
            *) # default: 
                echo "error"
                exit 1
                ;;
        esac
    done
}

function validar_parametros() {
    if [[ -z "$directorio" || "$directorio" == -* ]]; then
        echo "Error: Debe especificar el directorio con las encuestas a procesar con -d o --directorio"
        exit 1
    fi

    if [[ -z "$archivo" && $pantalla -eq 0 ]];then
        echo "Error: Debe ingresar -a (archivo) o -p (pantalla) para la salida"
        exit 1
    fi

    if [[ -n "$archivo" && $pantalla -eq 1 ]];then
        echo "Error: No puede usar -a y -p al mismo tiempo, elija una sola salida"
        exit 1
    fi

    directorio=$(realpath "$directorio" 2>/dev/null) #covierte la ruta relativa en absoluta (para que soporte absolutas y relativas)
    if [[ ! -d "$directorio" ]]; then
        echo "Error: El directorio $directorio no existe"
        exit 1
    fi
    if ! ls "$directorio"/*.txt 1>/dev/null 2>&1; then
        echo "No hay archivos .txt en $directorio"
        exit 1
    fi

    if [[ $archivo && "$archivo" != *.json ]]; then
        echo "El archivo de salida debe tener extensión .json"
        exit 1
    fi

}

function procesar_encuestas() {
    awk -F'|' '
    NF != 5 {
        print "Línea mal formateada (salteada): " $0 > "/dev/stderr"
        next
    }
    {
        fecha=substr($2,1,10)
        canal=$3
        tiempo[fecha][canal]+=$4
        nota[fecha][canal]+=$5
        count[fecha][canal]++
    }
    END{
        fcount = 0
        printf "{\n"
        for(fecha in tiempo){
            if (fcount++ > 0) printf ",\n"
            printf "  \"%s\": {\n", fecha
            ccount=0
            #printf "\"%s\": {\n", fecha
            for(canal in tiempo[fecha]){
                if (ccount++ > 0) printf ",\n"
                printf "\t\"%s\": {\n", canal
                tiempoProm = tiempo[fecha][canal] / count[fecha][canal]
                notaProm = nota[fecha][canal] / count[fecha][canal]

                # Mostrar como entero si no tiene decimales
                if (tiempoProm == int(tiempoProm)) {
                    printf "\t\t\"tiempo_respuesta_promedio\": %d,\n", tiempoProm
                } else {
                    printf "\t\t\"tiempo_respuesta_promedio\": %.1f,\n", tiempoProm
                }
                if (notaProm == int(notaProm)) {
                    printf "\t\t\"nota_satisfaccion_promedio\": %d\n", notaProm
                } else {
                    printf "\t\t\"nota_satisfaccion_promedio\": %.1f\n", notaProm
                }

                printf "    }"
            }
            printf "\n  }"
        }
        printf "\n}\n"
    }' "$directorio"/*.txt
}

# ----------
opciones_parametros "$@"
validar_parametros

resultado=$(procesar_encuestas)

if [[ $pantalla -eq 1 ]];then
    echo "$resultado"
else
    echo "$resultado" > "$archivo"
    echo "Salida guardada en $archivo"
fi 


