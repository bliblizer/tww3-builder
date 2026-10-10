-- Statistiques des unités jouables, calculées à partir des tables du jeu (panneau de gauche du builder).
-- Grain : 1 ligne par unité (clé d'unité). Vérifié sur les captures du jeu (Dwarf Warriors, Ekrund Miners) et,
-- à la construction, contre les valeurs d'un export tiers (tww3 stats card) :
--   armure, commandement, attaque/défense de mêlée, charge, portée, rechargement : 100 % identiques
--   taille d'unité 99,8 %, vitesse 96 %, points de vie 88 %, puissance de tir 100 % (écarts : chars, machines de guerre, personnages
--   montés sur un char ou un engin, dont les engins ne sont pas encore pris en compte)

with units as (
    select distinct unit_key from {{ ref('pvp_roster_options') }}
),

base as (
    select
        m.unit_key, m.num_men, lu.*,
        man.hit_points  as man_hp,  man.run_speed  as man_run,  man.fly_speed  as man_fly,
        mte.hit_points  as mount_hp, mte.run_speed as mount_run, mte.fly_speed as mount_fly,
        arm.armour_value, sh.missile_block_chance
    from units u
    join {{ ref('stg_dump__main_units') }} m using (unit_key)
    join {{ ref('stg_dump__land_units') }} lu using (land_unit_key)
    left join {{ ref('stg_dump__battle_entities') }} man on man.battle_entity_key = lu.man_entity
    left join {{ ref('stg_dump__mounts') }} mo on mo.mount_key = lu.mount
    left join {{ ref('stg_dump__battle_entities') }} mte on mte.battle_entity_key = mo.battle_entity_key
    left join {{ ref('stg_dump__unit_armour_types') }} arm on arm.armour_key = lu.armour
    left join {{ ref('stg_dump__unit_shield_types') }} sh on sh.shield_key = lu.shield
),

melee as (
    select b.unit_key, w.damage, w.ap_damage, w.bonus_v_large, w.bonus_v_infantry
    from base b join {{ ref('stg_dump__melee_weapons') }} w on w.melee_weapon_key = b.primary_melee_weapon
),

missile as (
    -- puissance de tir affichée = dégâts d'une salve (projectile + explosion, normaux + perforants)
    --   x projectiles x tirs par salve x rafale x 10 / temps de rechargement (réduit par land_units.reload)
    select b.unit_key, b.primary_ammo, p.effective_range,
           p.base_reload_time * (1 - coalesce(b.reload, 0) / 100.0)                         as reload_time,
           (p.damage + p.ap_damage + coalesce(e.detonation_damage, 0) + coalesce(e.detonation_damage_ap, 0))
             * p.projectile_number * coalesce(nullif(p.shots_per_volley, 0), 1) * coalesce(nullif(p.burst_size, 0), 1) as volley_damage
    from base b
    join {{ ref('stg_dump__missile_weapons') }} mw on mw.missile_weapon_key = b.primary_missile_weapon
    join {{ ref('stg_dump__projectiles') }} p on p.projectile_key = mw.projectile_key
    left join {{ ref('stg_dump__projectiles_explosions') }} e on e.explosion_key = p.explosion_key
)

select
    b.unit_key,
    -- taille : engins (chars) > corps unique (1 monture pour l'unité) > nombre d'hommes
    case when b.num_engines > 0 then b.num_engines when b.num_mounts = 1 then 1 else b.num_men end   as unit_size,
    -- points de vie : soldats + montures + bonus par corps (monture si montée, sinon soldat)
    b.num_men * coalesce(b.man_hp, 0) + coalesce(b.num_mounts, 0) * coalesce(b.mount_hp, 0)
      + b.bonus_hit_points * case when b.num_mounts > 0 then b.num_mounts else b.num_men end         as health,
    -- vitesse : vitesse de vol si l'unité vole, sinon la plus grande vitesse de course (soldat ou monture), x 10
    round(10 * case when greatest(coalesce(b.man_fly, 0), coalesce(b.mount_fly, 0)) > 0
                    then greatest(coalesce(b.man_fly, 0), coalesce(b.mount_fly, 0))
                    else greatest(coalesce(b.man_run, 0), coalesce(b.mount_run, 0)) end)::int         as speed,
    b.armour_value                                                       as armour,
    nullif(b.missile_block_chance, 0)                                    as shield_block_chance,
    b.morale                                                             as leadership,
    b.melee_attack,
    b.melee_defence,
    me.damage + me.ap_damage                                             as weapon_strength,
    me.ap_damage                                                         as weapon_ap_damage,
    nullif(me.bonus_v_large, 0)                                          as bonus_v_large,
    nullif(me.bonus_v_infantry, 0)                                       as bonus_v_infantry,
    b.charge_bonus,
    case when mi.unit_key is not null then b.primary_ammo end            as ammunition,
    mi.effective_range                                                   as range,
    round(mi.volley_damage * 10 / nullif(mi.reload_time, 0))::int        as missile_strength,
    round(mi.reload_time, 2)                                             as reload_time,
    nullif(b.damage_mod_physical, 0)                                     as physical_resistance,
    nullif(b.damage_mod_magic, 0)                                        as spell_resistance,
    nullif(b.damage_mod_missile, 0)                                      as missile_resistance,
    nullif(b.damage_mod_flame, 0)                                        as fire_resistance,
    nullif(b.damage_mod_all, 0)                                          as ward_save,
    '{{ var("patch") }}'                                                 as patch
from base b
left join melee me using (unit_key)
left join missile mi using (unit_key)
