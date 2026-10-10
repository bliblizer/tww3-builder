-- Explosions des projectiles
-- Source : db/projectiles_explosions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as explosion_key,
    "detonator_type"                                        as detonator_type,
    "detonation_type"                                       as detonation_type,
    cast("detonation_radius" as decimal(18,4))              as detonation_radius,
    cast("detonation_duration" as decimal(18,4))            as detonation_duration,
    cast("detonation_speed" as decimal(18,4))               as detonation_speed,
    cast("detonation_damage" as decimal(18,4))              as detonation_damage,
    "shrapnel"                                              as shrapnel,
    "explosion_particle_effect"                             as explosion_particle_effect,
    cast("fuse_distance_from_target" as decimal(18,4))      as fuse_distance_from_target,
    "explosion_particle_effect_on_ground"                   as explosion_particle_effect_on_ground,
    "explosion_audio"                                       as explosion_audio,
    "contact_phase_effect"                                  as contact_phase_effect,
    cast("ignition_amount" as decimal(18,4))                as ignition_amount,
    cast("is_magical" as boolean)                           as is_magical,
    cast("detonation_damage_ap" as decimal(18,4))           as detonation_damage_ap,
    "camera_shake"                                          as camera_shake,
    cast("detonation_force" as decimal(18,4))               as detonation_force,
    cast("fuse_fixed_time" as decimal(18,4))                as fuse_fixed_time,
    cast("affects_allies" as boolean)                       as affects_allies,
    cast("is_spell" as boolean)                             as is_spell,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/projectiles_explosions_tables/data__.tsv') }}
