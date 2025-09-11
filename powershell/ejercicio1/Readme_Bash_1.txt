Consideraciones:

1-Instalar jq con sudo apt-get install jq       # Para distros Debian/Ubuntu/Mint

Esto sirve para para procesar archivos con formato JSON por linea de comandos.
En este script lo usamos para armar la salida en formato JSON válido a partir de los datos que agrupamos con AWK.
Ya que sin jq, tendriamos que usar echo para formar correctamente, como pide el enunciado, el formato de JSON y esto seria mas laborioso.


2- Se deben de crear los 4 lotes de pruebas establecidos para poner a prueba este analizador.
	Lo haremos con ./generaLotes.sh para luego ejecutar el analizador.


3- Para ejecutarlo se debe ingresar
	Para mostrar por pantalla:	 bash analizador_de_encuestas.sh -d "/ruta/a/encuestas" -p
	Para generar un archivo: 	 bash analizador_de_encuestas.sh -d "/ruta/a/encuestas" -a "./salida/resultados.json"

Si no se encuentra ningún archivo o todas las líneas son inválidas, devuelve {} y lo informa de forma amable.
