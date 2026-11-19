# OBJECT DATA MODEL
**Статус:** проект схемы; сверить с реальным экспортом.

## Принципы
- Постоянный `object_id`, не зависящий от URL, цены или имени файла.
- Контролируемые справочники типов и статусов.
- История изменений и источник записи.
- Фото — отдельные сущности, связанные с объектом.

## Поля объекта
| Поле | Тип | Обязательность |
|---|---|---|
| object_id | string/UUID | Да |
| title | string | Да |
| property_type | enum | Да |
| deal_type | enum | Да |
| price | decimal | По сценарию |
| currency | enum | Да |
| location | object | Да |
| area_total | decimal | Нет |
| bedrooms / bathrooms | integer | Нет |
| description | text | Нет |
| features | array | Нет |
| status | enum | Да |
| manager_id | string | Нет |
| source_system / source_record_id | string | Да / нет |
| created_at / updated_at | datetime | Да |

## Фото
`media_id`, `object_id`, `file_name`, `storage_url`, `sort_order`, `role`, `alt_text`, `rights_status`, `source`, `created_at`.

## Предварительные статусы
`draft`, `pending_review`, `published`, `hidden`, `sold`, `archived`. Согласовать с процессами агентства.

## Проверить на тестовой выборке
Дубли, валюты и цены, пустые поля, несколько менеджеров, фото без объекта, история статусов и соответствие ID исходной системе.
