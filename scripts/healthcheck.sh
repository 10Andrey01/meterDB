#!/bin/bash
# Healthcheck скрипт для Docker контейнера

DB_NAME="meter_readings_db"

# Проверка доступности PostgreSQL
if pg_isready -U postgres -d $DB_NAME -h localhost -p 5432; then
    # Проверка существования ключевых таблиц
    if psql -U postgres -d $DB_NAME -t -c "SELECT COUNT(*) FROM meters_schema.clients" > /dev/null 2>&1; then
        exit 0
    else
        echo "Database tables not initialized"
        exit 1
    fi
else
    echo "PostgreSQL is not ready"
    exit 1
fi
