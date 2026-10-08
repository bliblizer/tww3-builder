-- Catégories d'objets
-- Source : db/ancillaries_categories_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "category"                                              as ancillary_category_key,
    "icon_name"                                             as icon_name,
    cast("sort_order" as bigint)                            as sort_order,
    cast("fusable" as boolean)                              as fusable,
    cast("hidden" as boolean)                               as hidden,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/ancillaries_categories_tables/data__.tsv') }}
