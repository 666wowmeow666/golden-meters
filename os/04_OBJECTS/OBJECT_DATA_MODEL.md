# OBJECT DATA MODEL
**Статус:** каноническая схема v0.2 · **Дата:** 19.11.2026  
**Назначение:** единая модель данных объектов для всей цифровой инфраструктуры GOLDEN METERS (сайт, Telegram, CRM, аналитика, AI, premium-презентации).

> Это **новая** база. Старая система (если существует) будет источником миграции, а не источником правды.

---

## 1. Принципы

1. **Постоянный `object_id`** (UUID) — никогда не меняется, не зависит от URL, цены, названия или файла.
2. **Один источник правды** — все каналы читают и пишут только через эту модель.
3. **Мягкое удаление** (`deleted_at`) + полная история изменений.
4. **Фото и медиа** — отдельные сущности с правами, ролями и источниками.
5. **Контролируемые справочники** + JSONB для гибких полей.
6. **Происхождение данных** — всегда фиксируем `source_system` + `source_record_id`.
7. **Готовность к росту** — лиды, публикации, история цен, комплексы, роли пользователей.
8. **Безопасность** — персональные данные клиентов и секреты в эту модель не попадают.

---

## 2. Справочники (enums / tables)

### 2.1 Типы объектов (`property_type`)
| code | name_ru |
|------|---------|
| villa | Вилла |
| apartment | Апартаменты / квартира |
| house | Дом |
| townhouse | Таунхаус |
| penthouse | Пентхаус |
| land | Участок |
| commercial | Коммерция |
| complex_unit | Квартира в ЖК |
| other | Другое |

### 2.2 Типы сделок (`deal_type`)
| code | name_ru |
|------|---------|
| sale | Продажа |
| rent | Аренда (краткосрочная) |
| long_rent | Долгосрочная аренда |
| investment | Инвестиционный объект |
| assignment | Переуступка |

### 2.3 Статусы объекта (`status`)
| code | name_ru | is_public | Описание |
|------|---------|-----------|----------|
| draft | Черновик | false | Создан, не готов |
| pending_review | На проверке | false | Ждёт подтверждения |
| published | Опубликован | true | Виден на сайте |
| hidden | Скрыт | false | Временно не показывается |
| reserved | Забронирован | false | Зарезервирован клиентом |
| sold | Продан | false | Сделка закрыта |
| rented | Сдан | false | Сдан в аренду |
| archived | Архив | false | Больше не актуален |

### 2.4 Роли медиа (`media.role`)
`main`, `gallery`, `plan`, `floor_plan`, `video`, `virtual_tour`, `drone`, `interior`, `exterior`, `view`, `document`

### 2.5 Статусы прав на медиа (`rights_status`)
`owned`, `licensed`, `client_provided`, `agency_photo`, `unknown`, `restricted`

### 2.6 Валюты
`RUB`, `USD`, `EUR` (основные). Можно расширять.

---

## 3. Основные сущности

### 3.1 objects

| Поле | Тип | Обязательность | Описание |
|------|-----|----------------|----------|
| object_id | uuid | PK | Постоянный идентификатор |
| title | text | Да | Название карточки |
| slug | text | Уникальный | Для URL (генерируется) |
| property_type | text | Да | Код из справочника |
| deal_type | text | Да | Код из справочника |
| status | text | Да | Код статуса |
| price | numeric(14,2) | Нет | Цена |
| currency | char(3) | Да | RUB / USD / EUR |
| price_on_request | boolean | Нет | Цена по запросу |
| price_per_sqm | numeric(12,2) | Нет | Можно вычислять |
| location | jsonb | Да | См. структуру ниже |
| area_total | numeric(10,2) | Нет | Общая площадь, м² |
| area_living | numeric(10,2) | Нет | Жилая |
| area_land | numeric(10,2) | Нет | Участок |
| bedrooms | smallint | Нет | |
| bathrooms | smallint | Нет | |
| floors_total | smallint | Нет | |
| floor | smallint | Нет | |
| year_built | smallint | Нет | |
| description | text | Нет | Полное описание |
| description_short | text | Нет | Краткое |
| features | text[] | Нет | Массив тегов (бассейн, вид на море, охрана…) |
| is_premium | boolean | Нет | Премиум-объект |
| is_exclusive | boolean | Нет | Эксклюзив |
| manager_id | uuid | Нет | Ответственный менеджер |
| source_system | text | Да | Откуда запись |
| source_record_id | text | Нет | ID в исходной системе |
| external_urls | jsonb | Нет | Ссылки на ЦИАН, Avito и т.д. |
| published_at | timestamptz | Нет | Когда впервые опубликован |
| created_at | timestamptz | Да | |
| updated_at | timestamptz | Да | |
| deleted_at | timestamptz | Нет | Soft delete |

#### Структура `location` (jsonb)
```json
{
  "city": "Сочи",
  "district": "Хостинский",
  "microdistrict": "Кудепста",
  "address": "ул. Примерная, 12",
  "complex_name": "Название ЖК",
  "lat": 43.123456,
  "lon": 39.987654,
  "sea_distance_m": 350,
  "notes": "5 минут до пляжа"
}
```

### 3.2 media

| Поле | Тип | Описание |
|------|-----|----------|
| media_id | uuid | PK |
| object_id | uuid | FK → objects |
| file_name | text | Оригинальное имя |
| storage_url | text | Полный URL или путь |
| storage_provider | text | s3 / cloudinary / local / yandex |
| mime_type | text | image/jpeg, video/mp4… |
| file_size | int | Байты |
| width / height | int | Для изображений |
| sort_order | int | Порядок в галерее |
| role | text | main / gallery / plan… |
| alt_text | text | Для SEO и доступности |
| caption | text | Подпись |
| rights_status | text | owned / licensed… |
| source | text | Откуда взято фото |
| is_active | boolean | |
| created_at | timestamptz | |
| created_by | uuid | Кто загрузил |

### 3.3 object_history (аудит)

| Поле | Тип | Описание |
|------|-----|----------|
| id | bigserial | PK |
| object_id | uuid | |
| changed_at | timestamptz | |
| changed_by | uuid | user_id |
| change_type | text | create / update / status_change / soft_delete / restore |
| old_values | jsonb | |
| new_values | jsonb | |
| comment | text | |

---

## 4. Индексы и ограничения (рекомендуемые)

- `objects(object_id)` — PK
- `objects(status)` where deleted_at is null
- `objects(property_type, deal_type)`
- `objects using gin (location)`
- `objects using gin (features)`
- `objects using gin (search_vector)` — полнотекст
- `media(object_id, sort_order)`
- `media(object_id) where role = 'main'`
- Уникальный `slug` среди не удалённых

---

## 5. Будущие сущности (закладываем сейчас)

- `users` / `managers` + роли
- `complexes` (ЖК)
- `price_history`
- `object_publications` (сайт, Telegram, Avito, Instagram…)
- `leads` / `inquiries` (заявки с привязкой к object_id)
- `object_features` (если features станут справочником)

---

## 6. Правила работы

1. Создание объекта → статус `draft`.
2. Публикация → только через статус `published` + запись в history.
3. Изменение цены / статуса → обязательно в history.
4. Удаление → только soft (`deleted_at`).
5. Фото без `object_id` не допускаются (или временный черновик).
6. `object_id` генерируется один раз и больше не меняется.
7. Все внешние системы используют только этот ID.

---

## 7. Миграция из текущей базы

Пока источник неизвестен. Стратегия:
1. Получить тестовую выборку 20–30 объектов.
2. Сопоставить поля.
3. Сгенерировать новые `object_id`.
4. Сохранить старый ID в `source_record_id`.
5. Перенести медиа с маппингом.
6. Проверить дубли, валюты, пустые обязательные поля.

---

## 8. Следующие артефакты

- `schema.sql` — полный DDL
- Seed справочников
- Правила генерации slug
- API-контракт (позже)

**Ответственный за актуальность модели:** ZERO28 STUDIO  
**Согласование с клиентом:** обязательно перед массовой миграцией.
