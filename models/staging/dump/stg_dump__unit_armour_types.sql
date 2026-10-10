-- Type d armure -> valeur d armure
-- Source : db/unit_armour_types_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as armour_key,
    cast("armour_value" as bigint)                          as armour_value,
    "audio_type"                                            as audio_type,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_armour_types_tables/data__.tsv') }}
