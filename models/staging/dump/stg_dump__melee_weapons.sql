-- Armes de mêlée (dégâts
-- Source : db/melee_weapons_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as melee_weapon_key,
    cast("bonus_v_large" as bigint)                         as bonus_v_large,
    cast("bonus_v_infantry" as bigint)                      as bonus_v_infantry,
    cast("damage" as bigint)                                as damage,
    cast("ap_damage" as bigint)                             as ap_damage,
    cast("weapon_length" as decimal(18,4))                  as weapon_length,
    "melee_weapon_type"                                     as melee_weapon_type,
    "audio_type"                                            as audio_type,
    "splash_attack_target_size"                             as splash_attack_target_size,
    cast("splash_attack_max_attacks" as bigint)             as splash_attack_max_attacks,
    cast("splash_attack_power_multiplier" as decimal(18,4)) as splash_attack_power_multiplier,
    cast("building_damage_multiplier" as decimal(18,4))     as building_damage_multiplier,
    cast("ignition_amount" as decimal(18,4))                as ignition_amount,
    cast("is_magical" as boolean)                           as is_magical,
    "contact_phase"                                         as contact_phase,
    cast("collision_attack_max_targets" as bigint)          as collision_attack_max_targets,
    cast("collision_attack_max_targets_cooldown" as bigint) as collision_attack_max_targets_cooldown,
    cast("melee_attack_interval" as decimal(18,4))          as melee_attack_interval,
    "scaling_damage"                                        as scaling_damage,
    cast("is_spell" as boolean)                             as is_spell,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/melee_weapons_tables/data__.tsv') }}
