# Declara objetivos que no representan archivos; Make siempre ejecutara sus comandos.
.PHONY: setup up down build migrate seed logs ps clean check

# Primera puesta en marcha o reconstruccion completa del entorno local.
# Construye las imagenes, inicia los servicios en segundo plano y espera su estado saludable.
setup:
	docker compose up -d --build --wait

# Inicia los servicios en segundo plano usando las imagenes existentes.
# No reconstruye imagenes ni espera a que todos los servicios esten saludables.
up:
	docker compose up -d

# Detiene y elimina los contenedores y la red del proyecto.
# Conserva los volumenes, incluida la base de datos local.
down:
	docker compose down

# Reconstruye las imagenes desde cero, sin reutilizar capas de la cache.
# No inicia ni detiene los servicios.
build:
	docker compose build --no-cache

# Ejecuta las migraciones pendientes de Laravel dentro del contenedor backend.
# --force permite ejecutarlas sin confirmacion interactiva; requiere que la base de datos este disponible.
migrate:
	docker compose exec backend php artisan migrate --force

# Ejecuta los seeders de Laravel una sola vez mientras se conserve el volumen backend_bootstrap.
# El marcador evita repetir la carga inicial; para volver a sembrar, revisa/elimina ese marcador manualmente.
seed:
	docker compose exec backend sh -lc 'if [ -f /var/lib/gotacna/seeded ]; then echo "Bootstrap seeder already ran"; else php artisan db:seed --force && touch /var/lib/gotacna/seeded; fi'

# Muestra en tiempo real los registros de todos los servicios.
# Pulsa Ctrl+C para dejar de seguirlos; esto no detiene los contenedores.
logs:
	docker compose logs -f

# Muestra los contenedores del proyecto y su estado actual.
ps:
	docker compose ps

# Comprueba que la configuracion de Docker Compose sea valida, sin iniciar servicios.
check:
	docker compose config --quiet

# Elimina contenedores, redes y volumenes, incluidos los datos de PostgreSQL.
# ADVERTENCIA: los datos locales de la base de datos se perderan y no se pueden recuperar desde este comando.
clean:
	docker compose down -v --remove-orphans