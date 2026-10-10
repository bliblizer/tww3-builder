-- Bouclier -> chance de bloquer les projectiles
-- Source : db/unit_shield_types_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as shield_key,
    cast("shield_defence_value" as bigint)                  as shield_defence_value,
    cast("shield_armour_value" as bigint)                   as shield_armour_value,
    cast("missile_block_chance" as bigint)                  as missile_block_chance,
    "audio_type"                                            as audio_type,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_shield_types_tables/data__.tsv') }}
