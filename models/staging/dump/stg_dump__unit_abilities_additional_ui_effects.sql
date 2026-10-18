-- Ordre et sens (positif / négatif) des points forts et faibles
-- Source : db/unit_abilities_additional_ui_effects_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as key,
    cast("sort_order" as bigint)                            as sort_order,
    "effect_state"                                          as effect_state,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_abilities_additional_ui_effects_tables/data__.tsv') }}
