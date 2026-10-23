#!/bin/sh
set -eu

cd /var/www/html

composer install --no-interaction --prefer-dist
php artisan config:clear
php artisan route:clear

# `php artisan serve` filtra las variables de entorno del contenedor y deja
# que el proceso PHP use únicamente el .env montado del host. Eso hacía que
# DB_HOST/CORE_API_URL de Docker Compose se ignoraran y las peticiones HTTP
# apuntaran a 127.0.0.1. Lanzamos el servidor embebido directamente para
# conservar el entorno del contenedor (PHP lo hereda del shell).
start_server() {
    cd /var/www/html/public
    exec php -S 0.0.0.0:8000 \
        /var/www/html/vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php
}

# El gateway Laravel solo reenvía peticiones al core: no tiene migraciones ni
# seeders propios. El core sí prepara PostgreSQL y carga los datos iniciales.
if [ "${APP_ROLE:-core}" = "gateway" ]; then
    start_server
fi

php artisan migrate --force

# El seeder de demostración es idempotente y solo se ejecuta si se pide de
# forma explícita. Así una base recreada vuelve a tener datos aunque el
# volumen de la aplicación se conserve, y producción nunca carga datos demo.
if [ "${SEED_DEMO_DATA:-false}" = "true" ]; then
    php artisan db:seed --force
fi

start_server
