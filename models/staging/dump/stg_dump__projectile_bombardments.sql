-- Bombardements des sorts : nombre et type de projectiles
-- Source : db/projectile_bombardments_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "bombardment_key"                                       as bombardment_key,
    cast("arrival_window" as decimal(18,4))                 as arrival_window,
    cast("num_projectiles" as bigint)                       as num_projectiles,
    "projectile_type"                                       as projectile_type,
    cast("radius_spread" as decimal(18,4))                  as radius_spread,
    cast("start_time" as decimal(18,4))                     as start_time,
    "launch_source"                                         as launch_source,
    "launch_vfx"                                            as launch_vfx,
    cast("launch_height" as bigint)                         as launch_height,
    "audio_type"                                            as audio_type,
    cast("launch_height_underground" as bigint)             as launch_height_underground,
    cast("randomise_launch" as boolean)                     as randomise_launch,
    cast("deterministic_launch_cadence" as boolean)         as deterministic_launch_cadence,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/projectile_bombardments_tables/data__.tsv') }}
