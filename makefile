# Makefile для управления Docker контейнером

.PHONY: help build up down start stop restart logs shell backup restore clean

help:
	@echo "Available commands:"
	@echo "  make build    - Build Docker image"
	@echo "  make up       - Start containers"
	@echo "  make down     - Stop and remove containers"
	@echo "  make start    - Start existing containers"
	@echo "  make stop     - Stop containers"
	@echo "  make restart  - Restart containers"
	@echo "  make logs     - Show logs"
	@echo "  make shell    - Connect to PostgreSQL shell"
	@echo "  make backup   - Create backup"
	@echo "  make restore  - Restore from backup"
	@echo "  make clean    - Remove containers, volumes and images"

build:
	docker-compose build --no-cache

up:
	docker-compose up -d
	@echo "Waiting for database to be ready..."
	sleep 10
	make shell

down:
	docker-compose down

start:
	docker-compose start

stop:
	docker-compose stop

restart:
	docker-compose restart

logs:
	docker-compose logs -f postgres

shell:
	docker-compose exec postgres psql -U postgres -d meter_readings_db

backup:
	docker-compose exec postgres /scripts/backup.sh

restore:
	@echo "Usage: make restore BACKUP_FILE=filename"
	docker-compose exec -e BACKUP_FILE=$(BACKUP_FILE) postgres /scripts/restore.sh /var/backups/postgres/$(BACKUP_FILE)

clean:
	docker-compose down -v
	docker system prune -f

status:
	docker-compose ps
	@echo ""
	@echo "Database status:"
	docker-compose exec postgres pg_isready -U postgres -d meter_readings_db

test:
	docker-compose exec postgres psql -U postgres -d meter_readings_db -c "SELECT * FROM meters_schema.current_readings LIMIT 5;"
