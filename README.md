# meterDB
PostgreSQL Database for Meter Readings Management

# Docker контейнер для PostgreSQL с БД показаний счетчиков

## Быстрый старт

### 1. Сборка и запуск
```bash
# Клонирование (или создание файлов в текущей директории)
# Переход в директорию с Docker файлами
cd docker-postgres-setup

# Запуск контейнера
make up

# Или через docker-compose
docker-compose up -d

# Через psql
make shell

# Или
docker-compose exec postgres psql -U postgres -d meter_readings_db

# Извне
psql -h localhost -p 5432 -U app_user -d meter_readings_db

# Просмотр статуса
make status

# Логи
make logs

# Остановка
make stop

# Запуск
make start

# Перезапуск
make restart

# Полное удаление
make clean

# Ручной бэкап
make backup

# Восстановление
make restore BACKUP_FILE=backup_meter_readings_db_20260529_153000.sql.gz

# Автоматический бэкап (настроен в docker-compose.yml)
# Выполняется ежедневно в 2:00

# Запуск с pgAdmin
docker-compose --profile monitoring up -d pgadmin

# Проверка healthcheck
docker-compose exec postgres /scripts/healthcheck.sh

# Выполнение тестовых запросов
make test

# Проверка подключений пользователей
docker-compose exec postgres psql -U app_user -d meter_readings_db -c "SELECT 1"[

# Проверка логов
docker-compose logs postgres

# Проверка свободного места
df -h

# Пересборка
make clean
make build
make up


