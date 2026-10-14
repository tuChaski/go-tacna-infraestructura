.PHONY: setup up down build migrate seed logs ps clean check

setup:
	docker compose up -d --build --wait

up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose build --no-cache

migrate:
	docker compose exec backend php artisan migrate --force

seed:
	docker compose exec backend sh -lc 'if [ -f /var/lib/gotacna/seeded ]; then echo "Bootstrap seeder already ran"; else php artisan db:seed --force && touch /var/lib/gotacna/seeded; fi'

logs:
	docker compose logs -f

ps:
	docker compose ps

check:
	docker compose config --quiet

clean:
	docker compose down -v --remove-orphans