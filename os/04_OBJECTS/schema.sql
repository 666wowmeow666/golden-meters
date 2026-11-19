-- GOLDEN METERS Object Data Model
-- PostgreSQL 16+
-- Version: 0.3 · 2026-11-19
-- Target: Yandex Managed PostgreSQL or Selectel Managed PostgreSQL
-- Media storage: Yandex Object Storage / Selectel S3

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. Reference tables
-- =====================================================

CREATE TABLE property_types (
    code        text PRIMARY KEY,
    name_ru     text NOT NULL,
    name_en     text,
    is_active   boolean NOT NULL DEFAULT true,
    sort_order  int DEFAULT 0
);

INSERT INTO property_types (code, name_ru, sort_order) VALUES
('villa',        'Вилла',              10),
('apartment',    'Апартаменты',        20),
('house',        'Дом',                30),
('townhouse',    'Таунхаус',           40),
('penthouse',    'Пентхаус',           50),
('land',         'Участок',            60),
('commercial',   'Коммерция',          70),
('complex_unit', 'Квартира в ЖК',      80),
('duplex',       'Дуплекс',            85),
('other',        'Другое',             90);

CREATE TABLE deal_types (
    code        text PRIMARY KEY,
    name_ru     text NOT NULL,
    is_active   boolean NOT NULL DEFAULT true,
    sort_order  int DEFAULT 0
);

INSERT INTO deal_types (code, name_ru, sort_order) VALUES
('sale',        'Продажа',                10),
('rent',        'Аренда (краткосрочная)', 20),
('long_rent',   'Долгосрочная аренда',    30),
('investment',  'Инвестиционный объект',  40),
('assignment',  'Переуступка',            50);

CREATE TABLE object_statuses (
    code        text PRIMARY KEY,
    name_ru     text NOT NULL,
    is_public   boolean NOT NULL DEFAULT false,
    sort_order  int DEFAULT 0
);

INSERT INTO object_statuses (code, name_ru, is_public, sort_order) VALUES
('draft',           'Черновик',       false, 10),
('pending_review',  'На проверке',    false, 20),
('published',       'Опубликован',    true,  30),
('hidden',          'Скрыт',          false, 40),
('reserved',        'Забронирован',   false, 50),
('sold',            'Продан',         false, 60),
('rented',          'Сдан',           false, 70),
('archived',        'Архив',          false, 80);

CREATE TABLE currencies (
    code        char(3) PRIMARY KEY,
    name_ru     text,
    symbol      text
);

INSERT INTO currencies (code, name_ru, symbol) VALUES
('RUB', 'Российский рубль', '₽'),
('USD', 'Доллар США',       '$'),
('EUR', 'Евро',             '€');

-- =====================================================
-- 2. Core: objects
-- =====================================================

CREATE TABLE objects (
    object_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    title               text NOT NULL,
    slug                text,

    property_type       text NOT NULL REFERENCES property_types(code),
    deal_type           text NOT NULL REFERENCES deal_types(code),
    status              text NOT NULL REFERENCES object_statuses(code) DEFAULT 'draft',

    price               numeric(14,2),
    currency            char(3) NOT NULL REFERENCES currencies(code) DEFAULT 'RUB',
    price_on_request    boolean NOT NULL DEFAULT false,
    price_per_sqm       numeric(12,2),

    location            jsonb NOT NULL DEFAULT '{}',

    area_total          numeric(10,2),
    area_living         numeric(10,2),
    area_land           numeric(10,2),
    bedrooms            smallint,
    bathrooms           smallint,
    floors_total        smallint,
    floor               smallint,
    year_built          smallint,

    description         text,
    description_short   text,
    features            text[] DEFAULT '{}',

    is_premium          boolean NOT NULL DEFAULT false,
    is_exclusive        boolean NOT NULL DEFAULT false,

    manager_id          uuid,

    source_system       text NOT NULL,
    source_record_id    text,
    external_urls       jsonb DEFAULT '{}',

    published_at        timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz,

    search_vector       tsvector,

    CONSTRAINT objects_slug_unique UNIQUE (slug),
    CONSTRAINT objects_price_check CHECK (
        price_on_request = true OR price IS NOT NULL
    )
);

CREATE INDEX idx_objects_status ON objects (status) WHERE deleted_at IS NULL;
CREATE INDEX idx_objects_property_deal ON objects (property_type, deal_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_objects_manager ON objects (manager_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_objects_location ON objects USING GIN (location);
CREATE INDEX idx_objects_features ON objects USING GIN (features);
CREATE INDEX idx_objects_search ON objects USING GIN (search_vector);
CREATE INDEX idx_objects_created ON objects (created_at DESC);
CREATE INDEX idx_objects_updated ON objects (updated_at DESC);

-- =====================================================
-- 3. Media
-- =====================================================

CREATE TABLE media (
    media_id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    object_id           uuid NOT NULL REFERENCES objects(object_id) ON DELETE CASCADE,

    file_name           text NOT NULL,
    storage_url         text NOT NULL,
    storage_provider    text,                     -- yandex, selectel, s3...
    mime_type           text,
    file_size           integer,
    width               integer,
    height              integer,

    sort_order          integer NOT NULL DEFAULT 0,
    role                text NOT NULL DEFAULT 'gallery',
    alt_text            text,
    caption             text,

    rights_status       text NOT NULL DEFAULT 'unknown',
    source              text,

    is_active           boolean NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid
);

CREATE INDEX idx_media_object ON media (object_id);
CREATE INDEX idx_media_object_sort ON media (object_id, sort_order);
CREATE INDEX idx_media_main ON media (object_id) WHERE role = 'main' AND is_active = true;

-- =====================================================
-- 4. History / Audit
-- =====================================================

CREATE TABLE object_history (
    id                  bigserial PRIMARY KEY,
    object_id           uuid NOT NULL,
    changed_at          timestamptz NOT NULL DEFAULT now(),
    changed_by          uuid,
    change_type         text NOT NULL,
    old_values          jsonb,
    new_values          jsonb,
    comment             text
);

CREATE INDEX idx_object_history_object ON object_history (object_id, changed_at DESC);
CREATE INDEX idx_object_history_changed_at ON object_history (changed_at DESC);

-- =====================================================
-- 5. Triggers
-- =====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_objects_updated_at
    BEFORE UPDATE ON objects
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION objects_search_vector_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('russian', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('russian', coalesce(NEW.description_short, '')), 'B') ||
        setweight(to_tsvector('russian', coalesce(NEW.description, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_objects_search_vector
    BEFORE INSERT OR UPDATE OF title, description, description_short ON objects
    FOR EACH ROW
    EXECUTE FUNCTION objects_search_vector_update();

-- =====================================================
-- Comments
-- =====================================================

COMMENT ON TABLE objects IS 'Канонические объекты недвижимости GOLDEN METERS';
COMMENT ON COLUMN objects.object_id IS 'Постоянный UUID. Никогда не меняется.';
COMMENT ON COLUMN objects.location IS 'JSONB: city, district, microdistrict, address, complex_name, lat, lon, sea_distance_m, notes';
COMMENT ON COLUMN objects.source_system IS 'Откуда пришла запись: manual, import_excel, old_site, telegram...';
COMMENT ON COLUMN objects.deleted_at IS 'Soft delete. NULL = активная запись';

COMMENT ON TABLE media IS 'Медиафайлы, привязанные к объектам';
COMMENT ON TABLE object_history IS 'Полный аудит изменений объектов';
