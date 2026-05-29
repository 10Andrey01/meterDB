-- =====================================================
-- Тестовые данные для разработки
-- =====================================================

-- Вставка тестовых клиентов
INSERT INTO meters_schema.clients (last_name, first_name, patronymic, birth_date, registration_address, residential_address, phone, is_client)
VALUES 
    ('Иванов', 'Иван', 'Иванович', '1980-05-15', 'г. Москва, ул. Ленина, д. 1, кв. 1', 'г. Москва, ул. Ленина, д. 1, кв. 1', '+7-495-123-45-67', TRUE),
    ('Петрова', 'Анна', 'Сергеевна', '1992-08-23', 'г. Санкт-Петербург, ул. Пушкина, д. 10, кв. 5', 'г. Санкт-Петербург, ул. Пушкина, д. 10, кв. 5', '+7-812-987-65-43', TRUE),
    ('Сидоров', 'Алексей', 'Владимирович', '1975-12-01', 'г. Казань, ул. Гоголя, д. 25', 'г. Казань, ул. Толстого, д. 7', '+7-843-555-12-34', FALSE),
    ('Козлова', 'Елена', 'Дмитриевна', '1988-03-10', 'г. Новосибирск, ул. Советская, д. 15', 'г. Новосибирск, ул. Советская, д. 15', '+7-383-222-33-44', TRUE),
    ('Морозов', 'Дмитрий', 'Александрович', '1995-07-19', 'г. Екатеринбург, ул. Ленина, д. 50', 'г. Екатеринбург, ул. Малышева, д. 12', '+7-343-777-88-99', TRUE);

-- Вставка тестовых счетчиков
INSERT INTO meters_schema.meters (meter_type, client_id, commissioning_date, decommissioning_date, is_commissioned)
VALUES 
    ('Электричество', 1, '2020-01-15', NULL, TRUE),
    ('Вода холодная', 1, '2020-01-15', '2023-12-31', FALSE),
    ('Вода горячая', 1, '2024-01-10', NULL, TRUE),
    ('Газ', 2, '2021-06-01', NULL, TRUE),
    ('Электричество', 2, '2021-06-01', NULL, TRUE),
    ('Электричество', 3, '2019-03-20', '2024-02-01', FALSE),
    ('Вода холодная', 4, '2022-01-15', NULL, TRUE),
    ('Электричество', 4, '2022-01-15', NULL, TRUE),
    ('Газ', 5, '2023-03-10', NULL, TRUE);

-- Вставка тестовых показаний
INSERT INTO meters_schema.readings (reading_date, client_id, meter_reading)
VALUES 
    -- Клиент 1
    ('2024-01-15', 1, 1250.500),
    ('2024-02-15', 1, 1320.300),
    ('2024-03-15', 1, 1390.750),
    ('2024-04-15', 1, 1460.200),
    ('2024-05-15', 1, 1530.600),
    
    -- Клиент 2
    ('2024-01-20', 2, 850.000),
    ('2024-02-20', 2, 920.250),
    ('2024-03-20', 2, 1005.600),
    ('2024-04-20', 2, 1090.100),
    ('2024-05-20', 2, 1180.450),
    
    -- Клиент 3 (не активный)
    ('2024-01-10', 3, 3000.000),
    ('2024-02-10', 3, 3100.000),
    
    -- Клиент 4
    ('2024-01-25', 4, 500.000),
    ('2024-02-25', 4, 550.750),
    ('2024-03-25', 4, 605.300),
    ('2024-04-25', 4, 660.800),
    ('2024-05-25', 4, 715.200),
    
    -- Клиент 5
    ('2024-02-01', 5, 2100.000),
    ('2024-03-01', 5, 2250.500),
    ('2024-04-01', 5, 2400.300),
    ('2024-05-01', 5, 2560.700);

-- Создание индекса для полнотекстового поиска
CREATE INDEX idx_clients_fulltext ON meters_schema.clients 
    USING GIN (to_tsvector('russian', last_name || ' ' || first_name || ' ' || COALESCE(patronymic, '')));

-- Создание функции для поиска клиентов
CREATE OR REPLACE FUNCTION meters_schema.search_clients(search_query TEXT)
RETURNS TABLE(
    id INTEGER,
    last_name VARCHAR,
    first_name VARCHAR,
    patronymic VARCHAR,
    phone VARCHAR,
    relevance REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.last_name,
        c.first_name,
        c.patronymic,
        c.phone,
        ts_rank(to_tsvector('russian', c.last_name || ' ' || c.first_name || ' ' || COALESCE(c.patronymic, '')), 
                plainto_tsquery('russian', search_query)) AS relevance
    FROM meters_schema.clients c
    WHERE to_tsvector('russian', c.last_name || ' ' || c.first_name || ' ' || COALESCE(c.patronymic, '')) @@ plainto_tsquery('russian', search_query)
    ORDER BY relevance DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;
