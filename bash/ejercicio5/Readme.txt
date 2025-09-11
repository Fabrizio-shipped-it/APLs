Un breve resumen al utilizar el script.

Se llama al script y este trae ciertos campos en particular como se muestra en el ejemplo del enunciado del ejercicio.

Esto va a crear un archivo con un TTL(time to live) que funciona como "cache" y se guarda en el directorio HOME del usuario actual.

Se van a guardar todas las consultas de los paises correctamente encontrados, en este directorio.

Si se venció el plazo establecido en el TTL se volvera a consultar a la API por esta informacion en caso de que el pais sea coincidente.
Caso contrario, se vuelve a levantar la informacion del propio archivo JSON generado que actua como "cache".

CONSIDERACION: El script valida que el TTL sea >0 para consultar la informacion en cache, sino se vuelve a consultar en la API y pisa esta informacion en el archivo JSON
ya creado, de esta forma actualizando la "cache". Pero los JSON se mantienen estaticos, es decir que no se "borran con el tiempo" simplemente estan ahi.

En caso de querer borrar estos archivos, se debera ir hasta el directorio y borrarlas manualmente con un rm *

Caso contrario, los archivos se mantendran ahi para ser nuevamente consultados o "renovados".