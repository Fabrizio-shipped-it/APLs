# APL - Bash y PowerShell (Virtualización de Hardware)

Actividad Práctica de Laboratorio de la cátedra **Virtualización de Hardware (3654)**, Departamento de Ingeniería e Investigaciones Tecnológicas, Universidad Nacional de La Matanza. 2° cuatrimestre, año 2025.

Consiste en 5 ejercicios de scripting de sistemas, cada uno resuelto **tanto en Bash como en PowerShell**, con los mismos parámetros y comportamiento en ambos lenguajes.

**Grupo 6:**

- Valle, Ramiro
- Parra, Ignacio
- Catari, Ezequiel Mohamed
- Blanco, Victoria Mariel
- Altamirano, Fabrizio Augusto

## Estructura del repositorio

```
APL FINAL/
├── APLS .pdf              # Enunciado original de la cátedra
├── bash/
│   ├── ejercicio1/         (+ lote de prueba)
│   ├── ejercicio2/         (+ lotes de prueba)
│   ├── ejercicio3/         (+ logs de prueba)
│   ├── ejercicio4/         (+ archivos de testing)
│   └── ejercicio5/         (+ Readme.txt propio)
└── powershell/
    ├── ejercicio1/  ...  ejercicio5/    (mismas pruebas que en bash)
```

Cada ejercicio en Bash tiene su equivalente en PowerShell con parámetros análogos (ver tabla de cada sección). Los scripts de Bash muestran ayuda con `-h`/`--help`; los de PowerShell la muestran con `Get-Help ./ejercicioN.ps1` (comment-based help nativo), y validan sus parámetros con `Param()`.

## Requisitos

- **Bash**: `awk`, `inotify-tools` (para el ejercicio 4), `curl` y `jq` (para el ejercicio 5).
- **PowerShell**: PowerShell 7+ (usa `ConvertTo-Json`, `FileSystemWatcher`, `Start-Job`, `Invoke-RestMethod`, etc.)

---

## Ejercicio 1 - Análisis de encuestas de satisfacción de clientes

Procesa archivos `.txt` con encuestas (formato `ID|FECHA|CANAL|TIEMPO_RESPUESTA|NOTA_SATISFACCION`, separadas por `|`) y calcula el tiempo de respuesta y la nota de satisfacción promedio, agrupados por fecha y canal de atención. La salida es JSON, por pantalla o a archivo.

| Parámetro bash | Parámetro PowerShell | Descripción |
|---|---|---|
| `-d`, `--directorio` | `-directorio` | Directorio con los archivos de encuestas a procesar |
| `-a`, `--archivo` | `-archivo` | Archivo JSON de salida (excluyente con `-p`/`-pantalla`) |
| `-p`, `--pantalla` | `-pantalla` | Muestra la salida por pantalla (excluyente con `-a`/`-archivo`) |

```bash
./ejercicio1.sh -d ./lote -p
./ejercicio1.sh -d ./lote -a resultados.json
```

```powershell
.\ejercicio1.ps1 -directorio ./lote -pantalla
.\ejercicio1.ps1 -directorio ./lote -archivo resultados.json
```

## Ejercicio 2 - Análisis de rutas en un mapa de transporte

Lee una matriz de adyacencia (archivo con los tiempos de viaje entre estaciones) y, según el parámetro elegido, determina la estación "hub" (con más conexiones) o el camino más corto entre la primera y la última estación usando el **algoritmo de Dijkstra**. El resultado se guarda en `informe.<nombreArchivoEntrada>` en el mismo directorio que la matriz.

| Parámetro bash | Parámetro PowerShell | Descripción |
|---|---|---|
| `-m`, `--matriz` | `-matriz` | Archivo con la matriz de adyacencia |
| `-h`, `--hub` | `-hub` | Determina la estación hub (excluyente con `-c`/`-camino`) |
| `-c`, `--camino` | `-camino` | Calcula el camino más corto (excluyente con `-h`/`-hub`) |
| `-s`, `--separador` | `-separador` | Separador de columnas (por defecto `\|`) |

```bash
./ejercicio2.sh -m ./lotes/mapa1.txt -h
./ejercicio2.sh -m ./lotes/mapa1.txt -c
```

La carpeta `lotes/` incluye 8 matrices de prueba y (en bash y powershell respectivamente) un script `run_tests.sh` / `run_tests.ps1` que corre ambos análisis sobre todas ellas, dejando los informes en `salidas_bash/` y `salidas_ps/`.

## Ejercicio 3 - Conteo de eventos en logs de sistema

Analiza todos los archivos `.log` de un directorio y cuenta cuántas veces aparece cada palabra clave de una lista (búsqueda **case-insensitive**). En Bash el conteo se resuelve con `awk`; concatena los logs en un archivo temporal en `/tmp` que se elimina al finalizar (`trap` de limpieza ante éxito o error).

| Parámetro bash | Parámetro PowerShell | Descripción |
|---|---|---|
| `-d`, `--directorio` | `-directorio` | Directorio con los archivos `.log` a analizar |
| `-p`, `--palabras` | `-palabras` | Palabras clave a contabilizar (en bash, separadas por comas) |

```bash
./ejercicio3.sh -d ./logs -p "usb,invalid"
```

## Ejercicio 4 - Análisis de seguridad de código en repositorios Git

Demonio que monitorea un repositorio en busca de credenciales o datos sensibles subidos por error (contraseñas, API keys, patrones regex configurables) y corre en segundo plano liberando la terminal. Cada vez que detecta una modificación en el repositorio, escanea los archivos cambiados contra la lista de patrones y, si hay coincidencia, registra una alerta (archivo, patrón y fecha) en el log indicado. Solo puede haber un demonio activo por repositorio, y se detiene con `-k`/`-kill`.

- **Bash**: usa `inotifywait` para detectar cambios en el repositorio y lanza el monitoreo en un subshell en segundo plano, guardando su PID en `/tmp/demonio_<repo>.pid`.
- **PowerShell**: usa `System.IO.FileSystemWatcher` + `Start-Job` para lograr el mismo comportamiento en segundo plano.

| Parámetro bash | Parámetro PowerShell | Descripción |
|---|---|---|
| `-r`, `--repo` | `-repo` | Repositorio Git a monitorear |
| `-c`, `--configuracion` | `-configuracion` | Archivo con la lista de patrones/palabras clave a buscar |
| `-l`, `--log` | `-log` | Archivo de log donde registrar las alertas |
| `-k`, `--kill` | `-kill` | Detiene el demonio activo para ese repositorio |

```bash
./ejercicio4.sh -r /home/user/myrepo -c ./patrones.conf -l ./patrones.log
./ejercicio4.sh -r /home/user/myrepo -k
```

El archivo de patrones admite tanto palabras literales como expresiones regulares (con el prefijo `regex:`), por ejemplo:

```
password
API_KEY
regex:^.*API_KEY\s*=\s*['"].*['"].*$
```

## Ejercicio 5 - Buscador de información de países

Consulta la API pública [REST Countries](https://restcountries.com/v3.1/name/{nombre}) para mostrar país, capital, región, población y moneda de uno o varios países. Los resultados se guardan en caché (con TTL configurable) para evitar consultas repetidas a la API mientras el caché siga vigente.

| Parámetro bash | Parámetro PowerShell | Descripción |
|---|---|---|
| `-n`, `--nombre` | `-nombre` | Nombre/s de país a buscar (admite lista separada por comas) |
| `-t`, `--ttl` | `-ttl` | Tiempo (en segundos) que se mantiene válido el caché (por defecto 86400 = 1 día) |

```bash
./buscador_paises.sh -n "Spain,Argentina" -t 3600
```

En Bash el caché se guarda como archivos JSON en `$XDG_CACHE_HOME/buscador_paises` (o `~/.cache/buscador_paises` si esa variable no está definida), uno por país consultado, con un timestamp que se compara contra el TTL en cada corrida. Si el TTL venció, se vuelve a consultar la API y se pisa el archivo; si no, se lee directo del caché. Los archivos de caché no se autoeliminan: para limpiarlos hay que borrarlos manualmente del directorio.

---

## Criterios de la consigna (resumen)

Además de lo funcional, la cátedra pidió: ayuda accesible en ambos lenguajes (`-h`/`--help` en bash, `Get-Help` en PowerShell), aceptar parámetros en cualquier orden, aceptar rutas relativas y absolutas, validar que los parámetros obligatorios estén presentes antes de ejecutar, manejar los errores de forma amigable (sin asumir conocimientos técnicos del usuario), y limpiar cualquier archivo temporal generado en `/tmp` al finalizar (con éxito o por error), tanto en Bash (`trap`) como en PowerShell (`try/catch/finally`).
