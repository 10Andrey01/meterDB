-- =====================================================
-- 1. Создание базы данных (выполняется от суперпользователя)
-- =====================================================
-- Создаём базу данных с кодировкой UTF-8
CREATE DATABASE meter_readings_db
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'ru_RU.UTF-8'
    LC_CTYPE = 'ru_RU.UTF-8'
    TEMPLATE = template0;

-- Подключаемся к новой базе данных
\c meter_readings_db

-- =====================================================
-- 2. Создание пользователей и ролей
-- =====================================================

-- 2.1. Роль для администратора (полный доступ)
CREATE ROLE admin_role WITH
    LOGIN
    SUPERUSER
    CREATEDB
    CREATEROLE
    PASSWORD 'AdminPass123!';

-- 2.2. Роль для приложения (CRUD операции)
CREATE ROLE app_user WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    PASSWORD 'AppUserPass456!';

-- 2.3. Роль для отчётов (только чтение)
CREATE ROLE report_user WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    PASSWORD 'ReportUserPass789!';

-- 2.4. Роль для обслуживания (бэкапы, мониторинг)
CREATE ROLE maintenance_role WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    PASSWORD 'MaintenancePass000!';

-- =====================================================
-- 3. Создание схемы данных
-- =====================================================

-- Создаём схему для приложения
CREATE SCHEMA IF NOT EXISTS meters_schema AUTHORIZATION admin_role;

-- Устанавливаем схему по умолчанию
SET search_path TO meters_schema;

-- =====================================================
-- 4. Создание таблиц (в схеме meters_schema)
-- =====================================================

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

-- =====================================================
-- 5. Создание индексов
-- =====================================================

CREATE INDEX idx_clients_names ON meters_schema.clients (last_name, first_name);
CREATE INDEX idx_clients_phone ON meters_schema.clients (phone);
CREATE INDEX idx_clients_is_client ON meters_schema.clients (is_client);
CREATE INDEX idx_readings_client_date ON meters_schema.readings (client_id, reading_date);
CREATE INDEX idx_readings_date ON meters_schema.readings (reading_date);
CREATE INDEX idx_meters_client_id ON meters_schema.meters (client_id);
CREATE INDEX idx_meters_decommission_status ON meters_schema.meters (decommissioning_date, is_commissioned);
CREATE INDEX idx_meters_commissioning_date ON meters_schema.meters (commissioning_date);

-- Составной индекс для сложных фильтров
CREATE INDEX idx_clients_names_phone ON meters_schema.clients (last_name, first_name, phone);

-- =====================================================
-- 6. Создание представлений
-- =====================================================

-- Текущие показания счетчиков
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

-- Активные клиенты с их счетчиками
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

-- =====================================================
-- 7. Настройка прав доступа
-- =====================================================

-- 7.1. Права для admin_role (уже есть полный доступ, но для порядка)
GRANT ALL PRIVILEGES ON SCHEMA meters_schema TO admin_role;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA meters_schema TO admin_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA meters_schema TO admin_role;

-- 7.2. Права для app_user (CRUD операции)
GRANT USAGE ON SCHEMA meters_schema TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA meters_schema TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA meters_schema TO app_user;
-- Для новых таблиц, которые будут созданы позже
ALTER DEFAULT PRIVILEGES IN SCHEMA meters_schema GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

-- 7.3. Права для report_user (только чтение)
GRANT USAGE ON SCHEMA meters_schema TO report_user;
GRANT SELECT ON ALL TABLES IN SCHEMA meters_schema TO report_user;
-- Для новых таблиц
ALTER DEFAULT PRIVILEGES IN SCHEMA meters_schema GRANT SELECT ON TABLES TO report_user;

-- 7.4. Права для maintenance_role (бэкапы, мониторинг, чтение)
GRANT USAGE ON SCHEMA meters_schema TO maintenance_role;
GRANT SELECT ON ALL TABLES IN SCHEMA meters_schema TO maintenance_role;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA meters_schema TO maintenance_role;

-- =====================================================
-- 8. Функция автоматического обновления updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION meters_schema.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для автоматического обновления updated_at
CREATE TRIGGER update_clients_updated_at
    BEFORE UPDATE ON meters_schema.clients
    FOR EACH ROW
    EXECUTE FUNCTION meters_schema.update_updated_at_column();

CREATE TRIGGER update_meters_updated_at
    BEFORE UPDATE ON meters_schema.meters
    FOR EACH ROW
    EXECUTE FUNCTION meters_schema.update_updated_at_column();

-- =====================================================
-- 9. Комментарии к таблицам и столбцам
-- =====================================================

COMMENT ON DATABASE meter_readings_db IS 'База данных для хранения показаний счетчиков клиентов';

COMMENT ON SCHEMA meters_schema IS 'Схема для хранения данных о клиентах, счетчиках и показаниях';

COMMENT ON TABLE meters_schema.clients IS 'Таблица с информацией о клиентах';
COMMENT ON COLUMN meters_schema.clients.last_name IS 'Фамилия клиента';
COMMENT ON COLUMN meters_schema.clients.first_name IS 'Имя клиента';
COMMENT ON COLUMN meters_schema.clients.patronymic IS 'Отчество клиента';
COMMENT ON COLUMN meters_schema.clients.birth_date IS 'Дата рождения клиента';
COMMENT ON COLUMN meters_schema.clients.registration_address IS 'Адрес регистрации';
COMMENT ON COLUMN meters_schema.clients.residential_address IS 'Адрес проживания';
COMMENT ON COLUMN meters_schema.clients.phone IS 'Номер телефона';
COMMENT ON COLUMN meters_schema.clients.is_client IS 'Флаг - является ли клиентом';

COMMENT ON TABLE meters_schema.meters IS 'Таблица с информацией о счетчиках';
COMMENT ON COLUMN meters_schema.meters.meter_type IS 'Вид счетчика (электричество, вода, газ и т.д.)';
COMMENT ON COLUMN meters_schema.meters.commissioning_date IS 'Дата ввода в эксплуатацию';
COMMENT ON COLUMN meters_schema.meters.decommissioning_date IS 'Дата вывода из эксплуатации';
COMMENT ON COLUMN meters_schema.meters.is_commissioned IS 'Введен ли в эксплуатацию';

COMMENT ON TABLE meters_schema.readings IS 'Таблица с показаниями счетчиков';
COMMENT ON COLUMN meters_schema.readings.reading_date IS 'Дата снятия показаний';
COMMENT ON COLUMN meters_schema.readings.meter_reading IS 'Значение показаний счетчика';

-- =====================================================
-- 10. Примеры тестовых данных (опционально)
-- =====================================================

INSERT INTO meters_schema.clients (last_name, first_name, patronymic, birth_date, registration_address, residential_address, phone, is_client)
VALUES 
    ('Иванов', 'Иван', 'Иванович', '1980-05-15', 'г. Москва, ул. Ленина, д. 1, кв. 1', 'г. Москва, ул. Ленина, д. 1, кв. 1', '+7-495-123-45-67', TRUE),
    ('Петрова', 'Анна', 'Сергеевна', '1992-08-23', 'г. Санкт-Петербург, ул. Пушкина, д. 10, кв. 5', 'г. Санкт-Петербург, ул. Пушкина, д. 10, кв. 5', '+7-812-987-65-43', TRUE),
    ('Сидоров', 'Алексей', 'Владимирович', '1975-12-01', 'г. Казань, ул. Гоголя, д. 25', 'г. Казань, ул. Толстого, д. 7', '+7-843-555-12-34', FALSE);

INSERT INTO meters_schema.meters (meter_type, client_id, commissioning_date, decommissioning_date, is_commissioned)
VALUES 
    ('Электричество', 1, '2020-01-15', NULL, TRUE),
    ('Вода холодная', 1, '2020-01-15', '2023-12-31', FALSE),
    ('Вода горячая', 1, '2024-01-10', NULL, TRUE),
    ('Газ', 2, '2021-06-01', NULL, TRUE),
    ('Электричество', 3, '2019-03-20', '2024-02-01', FALSE);

INSERT INTO meters_schema.readings (reading_date, client_id, meter_reading)
VALUES 
    ('2024-01-15', 1, 1250.500),
    ('2024-02-15', 1, 1320.300),
    ('2024-03-15', 1, 1390.750),
    ('2024-01-20', 2, 850.000),
    ('2024-02-20', 2, 920.250),
    ('2024-03-20', 2, 1005.600);

-- =====================================================
-- 11. Проверка прав доступа (информационные запросы)
-- =====================================================

-- Просмотр созданных пользователей
-- SELECT usename FROM pg_user;

-- Просмотр прав на схему
-- SELECT grantee, privilege_type FROM information_schema.schema_privileges WHERE schema_name = 'meters_schema';

-- Просмотр прав на таблицы
-- SELECT grantee, table_name, privilege_type FROM information_schema.table_privileges WHERE table_schema = 'meters_schema';

