#!/bin/sh
set -eu

cd /var/www/html

composer install --no-interaction --prefer-dist
php artisan config:clear
php artisan migrate --force

mkdir -p /var/lib/gotacna
if [ ! -f /var/lib/gotacna/seeded ]; then
    php artisan db:seed --force
    touch /var/lib/gotacna/seeded
fi

exec php artisan serve --host=0.0.0.0 --port=8000