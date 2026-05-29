#!/bin/bash
# Скрипт восстановления из бэкапа

BACKUP_FILE=$1
DB_NAME="meter_readings_db"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    echo "Available backups:"
    ls -lh /var/backups/postgres/backup_${DB_NAME}_*.sql.gz
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file $BACKUP_FILE not found!"
    exit 1
fi

echo "Restoring database $DB_NAME from $BACKUP_FILE"

# Восстановление
gunzip -c $BACKUP_FILE | PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U $POSTGRES_USER $DB_NAME

if [ $? -eq 0 ]; then
    echo "Restore completed successfully"
else
    echo "Restore failed!"
    exit 1
fi
