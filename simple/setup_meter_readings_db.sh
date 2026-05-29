#!/bin/bash

# =====================================================
# Скрипт для автоматической настройки PostgreSQL и заливки БД
# Название: setup_meter_readings_db.sh
# =====================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурационные переменные
DB_NAME="meter_readings_db"
DB_OWNER="postgres"
SQL_FILE="create_meter_readings_db.sql"
LOG_FILE="setup_db_$(date +%Y%m%d_%H%M%S).log"
PG_DATA_DIR="/var/lib/postgresql/data"
PG_CONF_FILE=""
PG_HBA_FILE=""

# Функция для логирования
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        log "${RED}ОШИБКА: $1${NC}"
        exit 1
    fi
}

# Функция для определения конфигурационных файлов PostgreSQL
find_pg_config_files() {
    if command -v pg_config &> /dev/null; then
        PG_VERSION=$(pg_config --version | grep -oP '\d+(\.\d+)?' | head -1)
        if [[ -f "/etc/postgresql/$PG_VERSION/main/postgresql.conf" ]]; then
            PG_CONF_FILE="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
            PG_HBA_FILE="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
        elif [[ -f "/var/lib/pgsql/$PG_VERSION/data/postgresql.conf" ]]; then
            PG_CONF_FILE="/var/lib/pgsql/$PG_VERSION/data/postgresql.conf"
            PG_HBA_FILE="/var/lib/pgsql/$PG_VERSION/data/pg_hba.conf"
        elif [[ -f "/var/lib/postgresql/data/postgresql.conf" ]]; then
            PG_CONF_FILE="/var/lib/postgresql/data/postgresql.conf"
            PG_HBA_FILE="/var/lib/postgresql/data/pg_hba.conf"
        else
            log "${YELLOW}Не удалось найти конфигурационные файлы PostgreSQL${NC}"
        fi
    fi
}

# Функция проверки зависимостей
check_dependencies() {
    log "${BLUE}[1/10] Проверка системных зависимостей...${NC}"
    
    # Проверка ОС
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log "Обнаружена ОС: $OS $VER"
    fi
    
    # Проверка PostgreSQL
    if command -v psql &> /dev/null; then
        PG_VERSION=$(psql --version | grep -oP '\d+(\.\d+)?' | head -1)
        log "${GREEN}✓ PostgreSQL найден (версия: $PG_VERSION)${NC}"
    else
        log "${YELLOW}PostgreSQL не установлен. Начинаю установку...${NC}"
        install_postgresql
    fi
    
    # Проверка необходимых утилит
    local deps=("pg_isready" "createdb" "dropdb" "psql" "grep" "awk" "sed")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "${YELLOW}Отсутствуют утилиты: ${missing_deps[*]}${NC}"
        log "${YELLOW}Устанавливаю дополнительные пакеты...${NC}"
        install_postgresql_contrib
    else
        log "${GREEN}✓ Все зависимости установлены${NC}"
    fi
}

# Функция установки PostgreSQL
install_postgresql() {
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
        check_error "Не удалось установить PostgreSQL"
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        sudo yum install -y postgresql-server postgresql-contrib
        sudo postgresql-setup --initdb
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
    elif command -v dnf &> /dev/null; then
        # Fedora
        sudo dnf install -y postgresql-server postgresql-contrib
        sudo postgresql-setup --initdb
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
    else
        log "${RED}Не удалось определить менеджер пакетов. Установите PostgreSQL вручную.${NC}"
        exit 1
    fi
    log "${GREEN}✓ PostgreSQL успешно установлен${NC}"
}

# Функция установки дополнительных утилит
install_postgresql_contrib() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y postgresql-contrib
    elif command -v yum &> /dev/null; then
        sudo yum install -y postgresql-contrib
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y postgresql-contrib
    fi
}

# Функция настройки параметров PostgreSQL
configure_postgresql() {
    log "${BLUE}[2/10] Настройка параметров PostgreSQL...${NC}"
    
    find_pg_config_files
    
    if [[ -f "$PG_CONF_FILE" ]]; then
        # Создание бэкапа конфигурации
        sudo cp "$PG_CONF_FILE" "${PG_CONF_FILE}.backup_$(date +%Y%m%d)"
        sudo cp "$PG_HBA_FILE" "${PG_HBA_FILE}.backup_$(date +%Y%m%d)"
        
        # Оптимизация параметров
        log "Настройка производительности..."
        
        # Расчет оптимальных параметров на основе доступной памяти
        TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
        SHARED_BUFFERS=$((TOTAL_RAM / 4))
        EFFECTIVE_CACHE_SIZE=$((TOTAL_RAM * 3 / 4))
        
        # Применение настроек
        sudo sed -i "s/^#shared_buffers =.*/shared_buffers = ${SHARED_BUFFERS}GB/" "$PG_CONF_FILE"
        sudo sed -i "s/^#effective_cache_size =.*/effective_cache_size = ${EFFECTIVE_CACHE_SIZE}GB/" "$PG_CONF_FILE"
        sudo sed -i "s/^#work_mem =.*/work_mem = 16MB/" "$PG_CONF_FILE"
        sudo sed -i "s/^#maintenance_work_mem =.*/maintenance_work_mem = 256MB/" "$PG_CONF_FILE"
        sudo sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" "$PG_CONF_FILE"
        sudo sed -i "s/^#max_connections =.*/max_connections = 200/" "$PG_CONF_FILE"
        sudo sed -i "s/^#log_directory =.*/log_directory = 'pg_log'/" "$PG_CONF_FILE"
        sudo sed -i "s/^#log_filename =.*/log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'/" "$PG_CONF_FILE"
        sudo sed -i "s/^#log_statement =.*/log_statement = 'ddl'/" "$PG_CONF_FILE"
        sudo sed -i "s/^#log_min_duration_statement =.*/log_min_duration_statement = 1000/" "$PG_CONF_FILE"
        
        # Настройка pg_hba.conf для разрешения подключений
        if grep -q "^host.*all.*all.*md5" "$PG_HBA_FILE"; then
            log "Настройки аутентификации уже присутствуют"
        else
            echo "# Разрешение подключений с локальной сети" | sudo tee -a "$PG_HBA_FILE"
            echo "host    all             all             127.0.0.1/32            md5" | sudo tee -a "$PG_HBA_FILE"
            echo "host    all             all             192.168.0.0/16           md5" | sudo tee -a "$PG_HBA_FILE"
        fi
        
        log "${GREEN}✓ Параметры PostgreSQL настроены${NC}"
        
        # Перезапуск PostgreSQL
        sudo systemctl restart postgresql
        check_error "Не удалось перезапустить PostgreSQL"
        sleep 3
    else
        log "${YELLOW}Конфигурационные файлы не найдены. Использую стандартные настройки.${NC}"
    fi
}

# Функция проверки статуса PostgreSQL
check_postgresql_status() {
    log "${BLUE}[3/10] Проверка статуса PostgreSQL...${NC}"
    
    if sudo systemctl is-active --quiet postgresql; then
        log "${GREEN}✓ PostgreSQL активен и работает${NC}"
    else
        log "${YELLOW}PostgreSQL не запущен. Запускаю...${NC}"
        sudo systemctl start postgresql
        sleep 2
        if sudo systemctl is-active --quiet postgresql; then
            log "${GREEN}✓ PostgreSQL успешно запущен${NC}"
        else
            log "${RED}Не удалось запустить PostgreSQL${NC}"
            exit 1
        fi
    fi
}

# Функция проверки существования БД
check_database_exists() {
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        return 0
    else
        return 1
    fi
}

# Функция создания/восстановления БД
setup_database() {
    log "${BLUE}[4/10] Подготовка базы данных...${NC}"
    
    if check_database_exists; then
        log "${YELLOW}База данных '$DB_NAME' уже существует${NC}"
        read -p "Удалить существующую БД и создать новую? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Удаление существующей базы данных..."
            sudo -u postgres dropdb --if-exists "$DB_NAME"
            check_error "Не удалось удалить БД"
            log "${GREEN}✓ База данных удалена${NC}"
        else
            log "${YELLOW}Пропускаем создание БД. Будет использована существующая.${NC}"
            return 0
        fi
    fi
    
    log "Создание базы данных '$DB_NAME'..."
    sudo -u postgres createdb -O "$DB_OWNER" "$DB_NAME"
    check_error "Не удалось создать БД"
    log "${GREEN}✓ База данных создана${NC}"
}

# Функция проверки SQL файла
check_sql_file() {
    log "${BLUE}[5/10] Проверка SQL файла...${NC}"
    
    if [[ ! -f "$SQL_FILE" ]]; then
        log "${RED}SQL файл '$SQL_FILE' не найден!${NC}"
        log "Текущая директория: $(pwd)"
        log "Файлы в директории:"
        ls -la
        exit 1
    fi
    
    # Проверка синтаксиса SQL файла
    log "Проверка синтаксиса SQL файла..."
    if sudo -u postgres psql -d postgres -f "$SQL_FILE" --echo-errors --set=ON_ERROR_STOP=on < /dev/null 2>&1 | grep -i "error"; then
        log "${RED}Обнаружены синтаксические ошибки в SQL файле${NC}"
        exit 1
    fi
    
    log "${GREEN}✓ SQL файл найден и проверен${NC}"
}

# Функция выполнения SQL скрипта
execute_sql_script() {
    log "${BLUE}[6/10] Выполнение SQL скрипта...${NC}"
    
    log "Импорт схемы и данных из $SQL_FILE"
    
    # Выполнение SQL скрипта с подробным логированием
    sudo -u postgres psql -d "$DB_NAME" -f "$SQL_FILE" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log "${GREEN}✓ SQL скрипт успешно выполнен${NC}"
    else
        log "${RED}Ошибка при выполнении SQL скрипта${NC}"
        exit 1
    fi
}

# Функция проверки созданных объектов
verify_database_objects() {
    log "${BLUE}[7/10] Проверка созданных объектов БД...${NC}"
    
    # Проверка таблиц
    local tables=("clients" "meters" "readings")
    for table in "${tables[@]}"; do
        local count=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'meters_schema' AND table_name = '$table';" 2>/dev/null | xargs)
        if [[ "$count" -eq 1 ]]; then
            log "${GREEN}✓ Таблица $table создана${NC}"
        else
            log "${RED}✗ Таблица $table не найдена${NC}"
        fi
    done
    
    # Проверка представлений
    local views=("current_readings" "active_clients_with_meters")
    for view in "${views[@]}"; do
        local exists=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'meters_schema' AND table_name = '$view';" 2>/dev/null | xargs)
        if [[ "$exists" -eq 1 ]]; then
            log "${GREEN}✓ Представление $view создано${NC}"
        else
            log "${YELLOW}⚠ Представление $view не найдено${NC}"
        fi
    done
    
    # Проверка пользователей
    local users=("admin_role" "app_user" "report_user" "maintenance_role")
    for user in "${users[@]}"; do
        local exists=$(sudo -u postgres psql -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_roles WHERE rolname = '$user';" 2>/dev/null | xargs)
        if [[ "$exists" -eq 1 ]]; then
            log "${GREEN}✓ Пользователь $user создан${NC}"
        else
            log "${YELLOW}⚠ Пользователь $user не найден${NC}"
        fi
    done
}

# Функция тестирования подключений
test_connections() {
    log "${BLUE}[8/10] Тестирование подключений пользователей...${NC}"
    
    # Тестовые данные для подключения
    local users_passwords=(
        "admin_role:AdminPass123!"
        "app_user:AppUserPass456!"
        "report_user:ReportUserPass789!"
        "maintenance_role:MaintenancePass000!"
    )
    
    for user_pass in "${users_passwords[@]}"; do
        IFS=':' read -r user pass <<< "$user_pass"
        log "Тестирование пользователя: $user"
        
        if PGPASSWORD="$pass" psql -h localhost -U "$user" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
            log "${GREEN}  ✓ Пользователь $user успешно подключился${NC}"
        else
            log "${RED}  ✗ Ошибка подключения для пользователя $user${NC}"
        fi
    done
}

# Функция выполнения тестовых запросов
run_test_queries() {
    log "${BLUE}[9/10] Выполнение тестовых запросов...${NC}"
    
    # Тестовый запрос 1: текущие показания
    log "Запрос 1: Текущие показания счетчиков (первые 5 записей)"
    sudo -u postgres psql -d "$DB_NAME" -c "SELECT last_name, first_name, meter_reading, reading_date FROM meters_schema.current_readings LIMIT 5;" 2>&1 | tee -a "$LOG_FILE"
    
    # Тестовый запрос 2: активные клиенты
    log "Запрос 2: Активные клиенты"
    sudo -u postgres psql -d "$DB_NAME" -c "SELECT last_name, first_name, is_client, meter_type FROM meters_schema.active_clients_with_meters WHERE is_client = TRUE LIMIT 5;" 2>&1 | tee -a "$LOG_FILE"
    
    # Статистика БД
    log "Статистика базы данных:"
    sudo -u postgres psql -d "$DB_NAME" -c "
        SELECT 
            (SELECT COUNT(*) FROM meters_schema.clients) as total_clients,
            (SELECT COUNT(*) FROM meters_schema.meters) as total_meters,
            (SELECT COUNT(*) FROM meters_schema.readings) as total_readings;
    " 2>&1 | tee -a "$LOG_FILE"
}

# Функция создания бэкапа
create_backup() {
    log "${BLUE}[10/10] Создание резервной копии...${NC}"
    
    BACKUP_FILE="backup_${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql"
    
    log "Создание бэкапа в файл: $BACKUP_FILE"
    sudo -u postgres pg_dump -d "$DB_NAME" -F p -f "$BACKUP_FILE"
    check_error "Не удалось создать бэкап"
    
    # Сжатие бэкапа
    gzip "$BACKUP_FILE"
    log "${GREEN}✓ Бэкап создан: ${BACKUP_FILE}.gz${NC}"
    
    # Создание cron задачи для автоматического бэкапа (опционально)
    read -p "Создать cron задачу для ежедневного бэкапа? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "0 2 * * * sudo -u postgres pg_dump $DB_NAME | gzip > /home/$USER/backup_${DB_NAME}_\$(date +\%Y\%m\%d).sql.gz") | crontab -
        log "${GREEN}✓ Cron задача создана (ежедневный бэкап в 2:00)${NC}"
    fi
}

# Функция вывода итоговой информации
print_summary() {
    log "\n${GREEN}========================================${NC}"
    log "${GREEN}✅ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!${NC}"
    log "${GREEN}========================================${NC}"
    log "📊 Информация о БД:"
    log "   - Название БД: $DB_NAME"
    log "   - Схема: meters_schema"
    log "   - Владелец: $DB_OWNER"
    log ""
    log "👥 Пользователи и пароли:"
    log "   - admin_role (полный доступ): AdminPass123!"
    log "   - app_user (CRUD): AppUserPass456!"
    log "   - report_user (только чтение): ReportUserPass789!"
    log "   - maintenance_role (обслуживание): MaintenancePass000!"
    log ""
    log "🔧 Полезные команды:"
    log "   - Подключение к БД: psql -U app_user -d $DB_NAME -h localhost"
    log "   - Просмотр логов: tail -f $LOG_FILE"
    log "   - Восстановление бэкапа: gunzip -c backup_*.sql.gz | psql -U postgres -d $DB_NAME"
    log ""
    log "📁 Файлы:"
    log "   - Лог установки: $LOG_FILE"
    log "   - Бэкап БД: backup_${DB_NAME}_*.sql.gz"
    log "${GREEN}========================================${NC}"
}

# Функция обработки ошибок
error_handler() {
    log "${RED}========================================${NC}"
    log "${RED}❌ ОШИБКА ВЫПОЛНЕНИЯ НА ШАГЕ: $1${NC}"
    log "${RED}========================================${NC}"
    log "Проверьте лог файл для деталей: $LOG_FILE"
    exit 1
}

# Главная функция
main() {
    log "${BLUE}========================================${NC}"
    log "${BLUE}🚀 НАЧАЛО УСТАНОВКИ БАЗЫ ДАННЫХ${NC}"
    log "${BLUE}========================================${NC}"
    log "Дата и время: $(date)"
    log "Пользователь: $(whoami)"
    log "Директория: $(pwd)"
    log ""
    
    # Проверка прав sudo
    if ! sudo -n true 2>/dev/null; then
        log "${YELLOW}Требуются права sudo. Пожалуйста, введите пароль.${NC}"
        sudo -v
    fi
    
    # Выполнение шагов установки
    check_dependencies || error_handler "Проверка зависимостей"
    configure_postgresql || error_handler "Настройка PostgreSQL"
    check_postgresql_status || error_handler "Проверка статуса PostgreSQL"
    setup_database || error_handler "Создание базы данных"
    check_sql_file || error_handler "Проверка SQL файла"
    execute_sql_script || error_handler "Выполнение SQL скрипта"
    verify_database_objects || error_handler "Проверка объектов БД"
    test_connections || error_handler "Тестирование подключений"
    run_test_queries || error_handler "Тестовые запросы"
    create_backup || error_handler "Создание бэкапа"
    print_summary
    
    log "\n${GREEN}✨ Установка завершена! Время выполнения: $(date)${NC}"
}

# Запуск главной функции с обработкой ошибок
trap 'error_handler "Неожиданная ошибка на строке $LINENO"' ERR
main "$@"

