# Dockerfile для PostgreSQL с базой данных показаний счетчиков
FROM postgres:15-alpine

# Установка дополнительных утилит
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    postgresql-contrib \
    pgbackrest \
    && rm -rf /var/cache/apk/*

# Настройка локали
ENV LANG=ru_RU.utf8
ENV LC_ALL=ru_RU.UTF-8

# Создание директорий для скриптов и бэкапов
RUN mkdir -p /docker-entrypoint-initdb.d \
    && mkdir -p /var/backups/postgres \
    && mkdir -p /var/log/postgresql \
    && mkdir -p /scripts

# Копирование скриптов инициализации
COPY init-scripts/ /docker-entrypoint-initdb.d/
COPY scripts/ /scripts/

# Настройка прав на скрипты
RUN chmod +x /scripts/*.sh \
    && chmod +x /docker-entrypoint-initdb.d/*.sql 2>/dev/null || true

# Создание пользователя для бэкапов (не root)
RUN addgroup -g 1001 -S postgres_backup && \
    adduser -u 1001 -S postgres_backup -G postgres_backup && \
    chown -R postgres_backup:postgres_backup /var/backups/postgres

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /scripts/healthcheck.sh

# Экспорт порта
EXPOSE 5432

# Запуск PostgreSQL
CMD ["postgres"]
