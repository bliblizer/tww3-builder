-- Roster PvP : les options jouables de chaque carte (1 option = 1 clé d'unité, celle des fichiers .army_setup).
-- Grain : 1 ligne par race x unité SÉLECTIONNABLE en PvP.
-- Règle : on filtre d'abord (PvP uniquement), on calcule ensuite (libellé « On foot » selon les seules options PvP).

with options as (
    select * from {{ ref('int_unit_cards') }}
    where is_selectable_pvp
),

flying as (
    -- unité volante : l'entité de combat du soldat ou de sa monture a une vitesse de vol (fly_speed > 0)
    select distinct m.unit_key
    from {{ ref('stg_dump__main_units') }} m
    join {{ ref('stg_dump__land_units') }} lu using (land_unit_key)
    left join {{ ref('stg_dump__battle_entities') }} man on man.battle_entity_key = lu.man_entity
    left join {{ ref('stg_dump__mounts') }} mo on mo.mount_key = lu.mount
    left join {{ ref('stg_dump__battle_entities') }} mount_entity on mount_entity.battle_entity_key = mo.battle_entity_key
    where coalesce(man.fly_speed, 0) > 0 or coalesce(mount_entity.fly_speed, 0) > 0
),

cards_with_mounts as (
    select card_id, bool_or(mount_name is not null) as has_mounts
    from options group by card_id
)

select
    o.race_key,
    o.card_id,
    o.unit_key,
    o.unit_name,
    o.lore,
    o.mark,
    o.forest_spirit,
    o.other_variant,
    o.other_variant_category,
    case when c.has_mounts then coalesce(o.mount_name, 'On foot') end   as mount,
    o.is_general_unit_pvp                                              as can_be_general,
    o.caste_key,
    o.caste_key = 'lord'                                               as is_lord,   -- une armée n'a qu'un seul lord (validé en jeu)
    -- rôle dans la composition (panneau de statistiques de l'armée). Seuils de l'infanterie = choix de présentation :
    -- légère < 500, de ligne 500-899, d'élite >= 900 (prix de base multijoueur)
    case
        when o.caste_key = 'lord'                                        then 'lord'
        when o.caste_key = 'hero'                                        then 'hero'
        when o.caste_key in ('melee_infantry', 'monstrous_infantry') and o.multiplayer_cost < 500 then 'infantry_light'
        when o.caste_key in ('melee_infantry', 'monstrous_infantry') and o.multiplayer_cost < 900 then 'infantry_line'
        when o.caste_key in ('melee_infantry', 'monstrous_infantry')    then 'infantry_elite'
        when o.caste_key in ('missile_infantry', 'missile_cavalry')     then 'ranged'
        when o.caste_key = 'warmachine'                                  then 'artillery'
        when o.caste_key in ('melee_cavalry', 'chariot', 'monstrous_cavalry') then 'cavalry'
        when o.caste_key = 'monster'                                     then 'monster'
        when o.caste_key = 'war_beast'                                   then 'war_beast'
        else 'other'
    end                                                                as role,
    f.unit_key is not null                                             as is_flying,
    o.multiplayer_cost,
    o.faction_keys_pvp                                                 as faction_keys,
    img.unit_card,
    o.patch
from options o
join cards_with_mounts c using (card_id)
left join {{ ref('int_unit_card_images') }} img using (unit_key)
left join flying f using (unit_key)
