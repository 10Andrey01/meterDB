#!/bin/bash
# Скрипт резервного копирования

BACKUP_DIR="/var/backups/postgres"
DB_NAME="meter_readings_db"
BACKUP_FILE="${BACKUP_DIR}/backup_${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql.gz"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

echo "Starting backup of $DB_NAME at $(date)"

# Создание бэкапа
PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h localhost -U $POSTGRES_USER $DB_NAME | gzip > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $BACKUP_FILE"
    
    # Удаление старых бэкапов
    find $BACKUP_DIR -name "backup_${DB_NAME}_*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    echo "Removed backups older than $RETENTION_DAYS days"
else
    echo "Backup failed!"
    exit 1
fi

echo "Backup finished at $(date)"
