-- Catégories de variantes
-- Source : db/units_custom_battle_type_categories_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "category_key"                                          as type_category_key,
    cast("is_horizontal_group" as boolean)                  as is_horizontal_group,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/units_custom_battle_type_categories_tables/data__.tsv') }}
