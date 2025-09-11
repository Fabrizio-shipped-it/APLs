Para empezar, este daemon solo funciona para repositorios locales, asi que si quisieramos usarlo en un entorno, habria que bajar un repositorio real de github y correrlo.

Pero en este caso, lo intentaremos con un repositorio ficticio para comprobar su funcionamiento.

Guia de pasos:

1) Preparar un entorno de prueba seguro
	mkdir -p ~/test_repo
	cd ~/test_repo
	git init


2) Crear algunos archivos de ejemplo con contenido que incluya los patrones a detectar
	echo "API_KEY='123456'" > config.js
	echo "password='miPassword'" > secrets.txt
	echo "No hay nada sensible aquí" > normal.txt
	git add .
	git commit -m "Primer commit de prueba"

3) Crear un archivo de configuración de patrones #Puede estar 
	cat > ~/patrones.conf <<'EOF'	#Esto redirige todo al nuevo archivo de configuration
	password
	API_KEY
	secret
	regex:^.*API_KEY\s*=\s*['"].*['"].*$
	EOF

4) Ejecutar el script en modo demonio
	./analizador_de_repos.sh -r "/rutaRepo" -c "/RutaDePatrones.conf" -l "/RutaDeRegistro.Log" &	# Escribir & hace que el daemon se ejecute en segundo plano


5) Generar cambios para probar detecciones

Pasamos a generar un cambio en un archivo que contenga un patrón como el que establecimos en el archivo .conf para verificar si el daemon funciona:
	echo "API_KEY='abcdef'" >> config.js
	git add config.js
	git commit -m "Segundo commit con clave"

El script debería detectar este patrón y registrar una alerta en "/RutaDeRegistro.log"


6) Chequear resultados

	cat "/RutaDeRegistro.log"

Se deberia ver algo como [2025-08-23 11:30:00] Alerta: patrón 'API_KEY' encontrado en el archivo 'config.js'.


7) ¡¡IMPORTANTE!! Para detener al daemon 

	./analizador_de_repos.sh -r "/rutaRepo" -k

Esto mata el proceso demonio para no seguir ejecutandose.

