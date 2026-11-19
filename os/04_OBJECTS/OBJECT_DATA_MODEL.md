# OBJECT DATA MODEL
**Статус:** каноническая схема v0.3 · **Дата:** 19.11.2026  
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

## 2. Инфраструктурное решение (зафиксировано 19.11.2026)

**Выбранный вариант:** российский managed PostgreSQL + Object Storage.

- **База данных:** Yandex Managed PostgreSQL **или** Selectel Managed PostgreSQL  
  (полное соответствие 152-ФЗ, данные физически в РФ)
- **Медиафайлы:** Yandex Object Storage **или** Selectel S3-compatible storage + CDN

Почему:
- С первого дня готовы к хранению персональных данных (лиды, контакты)
- Предсказуемая стоимость и поддержка
- Не нужно мигрировать позже

Альтернативы (отложены): Supabase / Neon — только если потребуется сверхбыстрый прототип без ПДн.

---

## 3. Справочники (enums) — финальные

### 3.1 Типы объектов (`property_type`)
| code | name_ru |
|------|---------|
| villa | Вилла |
| apartment | Апартаменты |
| house | Дом |
| townhouse | Таунхаус |
| penthouse | Пентхаус |
| land | Участок |
| commercial | Коммерция |
| complex_unit | Квартира в ЖК |
| duplex | Дуплекс |
| other | Другое |

### 3.2 Типы сделок (`deal_type`)
| code | name_ru |
|------|---------|
| sale | Продажа |
| rent | Аренда (краткосрочная) |
| long_rent | Долгосрочная аренда |
| investment | Инвестиционный объект |
| assignment | Переуступка |

### 3.3 Статусы объекта (`status`)
| code | name_ru | is_public |
|------|---------|-----------|
| draft | Черновик | false |
| pending_review | На проверке | false |
| published | Опубликован | true |
| hidden | Скрыт | false |
| reserved | Забронирован | false |
| sold | Продан | false |
| rented | Сдан | false |
| archived | Архив | false |

### 3.4 Роли медиа (`media.role`)
`main`, `gallery`, `plan`, `floor_plan`, `video`, `virtual_tour`, `drone`, `interior`, `exterior`, `view`, `document`

### 3.5 Статусы прав на медиа (`rights_status`)
`owned`, `agency_photo`, `client_provided`, `licensed`, `restricted`, `unknown`

### 3.6 Валюты
`RUB`, `USD`, `EUR`

---

## 4. Основные сущности

### 4.1 objects

| Поле | Тип | Обязательность | Описание |
|------|-----|----------------|----------|
| object_id | uuid | PK | Постоянный идентификатор |
| title | text | Да | Название карточки |
| slug | text | Уникальный | Для URL |
| property_type | text | Да | Код из справочника |
| deal_type | text | Да | Код из справочника |
| status | text | Да | Код статуса |
| price | numeric(14,2) | Нет | Цена |
| currency | char(3) | Да | RUB / USD / EUR |
| price_on_request | boolean | Нет | Цена по запросу |
| price_per_sqm | numeric(12,2) | Нет | |
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
| features | text[] | Нет | Массив тегов |
| is_premium | boolean | Нет | Премиум-объект |
| is_exclusive | boolean | Нет | Эксклюзив |
| manager_id | uuid | Нет | Ответственный менеджер |
| source_system | text | Да | Откуда запись |
| source_record_id | text | Нет | ID в исходной системе |
| external_urls | jsonb | Нет | Ссылки на внешние площадки |
| published_at | timestamptz | Нет | |
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

### 4.2 media

| Поле | Тип | Описание |
|------|-----|----------|
| media_id | uuid | PK |
| object_id | uuid | FK → objects |
| file_name | text | Оригинальное имя |
| storage_url | text | Полный URL |
| storage_provider | text | yandex / selectel / s3… |
| mime_type | text | |
| file_size | int | |
| width / height | int | |
| sort_order | int | |
| role | text | main / gallery / plan… |
| alt_text | text | |
| caption | text | |
| rights_status | text | |
| source | text | |
| is_active | boolean | |
| created_at | timestamptz | |
| created_by | uuid | |

### 4.3 object_history (аудит)

Полная история изменений: кто, когда, что изменил (old_values / new_values).

---

## 5. Индексы и правила

- Soft delete через `deleted_at`
- Уникальный `slug` среди активных записей
- GIN-индексы на `location` и `features`
- Полнотекстовый поиск (`search_vector`)
- Триггеры `updated_at` и обновления search_vector

---

## 6. Будущие сущности

- `users` / `managers` + роли
- `complexes`
- `price_history`
- `object_publications`
- `leads` / `inquiries`

---

## 7. Правила работы

1. Создание → `draft`
2. Публикация → только через смену статуса + запись в history
3. Изменение цены / статуса → обязательно в history
4. Удаление → только soft
5. `object_id` генерируется один раз
6. Все системы используют только этот ID

---

## 8. Миграция

1. Получить тестовую выборку 20–30 объектов
2. Сопоставить поля
3. Сгенерировать новые `object_id`
4. Сохранить старый ID в `source_record_id`
5. Перенести медиа
6. Проверить качество данных

**Ответственный:** ZERO28 STUDIO  
**Согласование с клиентом:** обязательно перед массовой миграцией.
