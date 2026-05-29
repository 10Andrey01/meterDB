-- =====================================================
-- Инициализация базы данных meter_readings_db
-- Скрипт выполняется автоматически при первом запуске контейнера
-- =====================================================

-- Создание схемы
CREATE SCHEMA IF NOT EXISTS meters_schema;

-- Таблица "Клиенты"
CREATE TABLE meters_schema.clients (
    id SERIAL PRIMARY KEY,
    last_name VARCHAR(50) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    patronymic VARCHAR(50),
    birth_date DATE NOT NULL,
    registration_address TEXT NOT NULL,
    residential_address TEXT NOT NULL,
    phone VARCHAR(20),
    is_client BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица "Счетчики"
CREATE TABLE meters_schema.meters (
    id SERIAL PRIMARY KEY,
    meter_type VARCHAR(100) NOT NULL,
    client_id INTEGER NOT NULL REFERENCES meters_schema.clients(id) ON DELETE CASCADE,
    commissioning_date DATE NOT NULL,
    decommissioning_date DATE,
    is_commissioned BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица "Показания счетчиков"
CREATE TABLE meters_schema.readings (
    id SERIAL PRIMARY KEY,
    reading_date DATE NOT NULL,
    client_id INTEGER NOT NULL REFERENCES meters_schema.clients(id) ON DELETE CASCADE,
    meter_reading NUMERIC(12, 3) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (client_id, reading_date)
);

-- Создание индексов
CREATE INDEX idx_clients_names ON meters_schema.clients (last_name, first_name);
CREATE INDEX idx_clients_phone ON meters_schema.clients (phone);
CREATE INDEX idx_clients_is_client ON meters_schema.clients (is_client);
CREATE INDEX idx_readings_client_date ON meters_schema.readings (client_id, reading_date);
CREATE INDEX idx_readings_date ON meters_schema.readings (reading_date);
CREATE INDEX idx_meters_client_id ON meters_schema.meters (client_id);
CREATE INDEX idx_meters_decommission_status ON meters_schema.meters (decommissioning_date, is_commissioned);
CREATE INDEX idx_meters_commissioning_date ON meters_schema.meters (commissioning_date);
CREATE INDEX idx_clients_names_phone ON meters_schema.clients (last_name, first_name, phone);

-- Создание представлений
CREATE VIEW meters_schema.current_readings AS
SELECT DISTINCT ON (r.client_id)
    c.id AS client_id,
    c.last_name,
    c.first_name,
    c.patronymic,
    c.phone,
    r.reading_date,
    r.meter_reading,
    m.meter_type
FROM meters_schema.readings r
JOIN meters_schema.clients c ON c.id = r.client_id
LEFT JOIN meters_schema.meters m ON m.client_id = c.id AND m.is_commissioned = TRUE
ORDER BY r.client_id, r.reading_date DESC;

CREATE VIEW meters_schema.active_clients_with_meters AS
SELECT 
    c.id,
    c.last_name,
    c.first_name,
    c.patronymic,
    c.phone,
    c.residential_address,
    c.is_client,
    m.id AS meter_id,
    m.meter_type,
    m.commissioning_date,
    m.decommissioning_date,
    m.is_commissioned
FROM meters_schema.clients c
LEFT JOIN meters_schema.meters m ON c.id = m.client_id
WHERE c.is_client = TRUE;

-- Функция обновления updated_at
CREATE OR REPLACE FUNCTION meters_schema.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры
CREATE TRIGGER update_clients_updated_at
    BEFORE UPDATE ON meters_schema.clients
    FOR EACH ROW
    EXECUTE FUNCTION meters_schema.update_updated_at_column();

CREATE TRIGGER update_meters_updated_at
    BEFORE UPDATE ON meters_schema.meters
    FOR EACH ROW
    EXECUTE FUNCTION meters_schema.update_updated_at_column();

-- =====================================================
-- Создание пользователей и настройка прав
-- =====================================================

-- Роли пользователей
CREATE ROLE admin_role WITH LOGIN SUPERUSER PASSWORD :'ADMIN_PASSWORD';
CREATE ROLE app_user WITH LOGIN NOSUPERUSER PASSWORD :'APP_USER_PASSWORD';
CREATE ROLE report_user WITH LOGIN NOSUPERUSER PASSWORD :'REPORT_USER_PASSWORD';
CREATE ROLE maintenance_role WITH LOGIN NOSUPERUSER PASSWORD :'MAINTENANCE_PASSWORD';

-- Права доступа
GRANT ALL PRIVILEGES ON SCHEMA meters_schema TO admin_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA meters_schema TO admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA meters_schema TO admin_role;

GRANT USAGE ON SCHEMA meters_schema TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA meters_schema TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA meters_schema TO app_user;

GRANT USAGE ON SCHEMA meters_schema TO report_user;
GRANT SELECT ON ALL TABLES IN SCHEMA meters_schema TO report_user;

GRANT USAGE ON SCHEMA meters_schema TO maintenance_role;
GRANT SELECT ON ALL TABLES IN SCHEMA meters_schema TO maintenance_role;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA meters_schema TO maintenance_role;

-- Комментарии
COMMENT ON DATABASE meter_readings_db IS 'База данных для хранения показаний счетчиков клиентов';
COMMENT ON SCHEMA meters_schema IS 'Схема для хранения данных о клиентах, счетчиках и показаниях';
