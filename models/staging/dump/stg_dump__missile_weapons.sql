-- Armes de tir -> projectile
-- Source : db/missile_weapons_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as missile_weapon_key,
    cast("precursor" as boolean)                            as precursor,
    "default_projectile"                                    as projectile_key,
    "audio_type"                                            as audio_type,
    cast("use_secondary_ammo_pool" as boolean)              as use_secondary_ammo_pool,
    cast("hide_secondary_range_ammo_statistics_ui" as boolean) as hide_secondary_range_ammo_statistics_ui,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/missile_weapons_tables/data__.tsv') }}
