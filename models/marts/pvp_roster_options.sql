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

portraits as (
    -- portrait du personnage (permissions de bataille : general_portrait) ; sert d'image quand la carte du jeu est
    -- « placeholder » (le jeu construit alors la carte d'un personnage à partir de son portrait, dans ui/portraits/units)
    select unit_key,
           any_value(regexp_extract(replace(general_portrait, chr(92), '/'), '([^/]+)\.png$', 1)) as portrait_image
    from {{ ref('stg_dump__units_custom_battle_permissions') }}
    where general_portrait is not null
    group by unit_key
),

category_icons as (
    -- icône de catégorie affichée en bas de la carte (fichier ui/common ui/unit_category_icons/<icône>) :
    -- personnage avec une icône de type (ex. domaine de magie : wh3_main_lore_slaanesh) -> cette icône ;
    -- sinon l'icône du sous-groupe d'interface de l'unité (ui_unit_groupings.icon)
    select m.unit_key,
           m.is_renown,
           coalesce(nullif(regexp_extract(replace(a.small_icon, chr(92), '/'), '([^/]+)\.png$', 1), ''), g.icon) as category_icon
    from {{ ref('stg_dump__main_units') }} m
    left join {{ ref('stg_dump__ui_unit_groupings') }} g using (ui_group_key)
    left join (select distinct c.unit_key, any_value(st.small_icon) over (partition by c.unit_key) as small_icon
               from {{ ref('int_character_agent_subtypes') }} c
               join {{ ref('stg_dump__agent_subtypes') }} st using (agent_subtype_key)) a using (unit_key)
),

lore_groups as (
    -- domaine de magie de l'option : son icône (passif du domaine) et sa couleur, comme dans le panneau du jeu
    select m.unit_key,
           -- groupe retenu : celui dont l'icône est le passif du domaine (« lore_passive »), sinon le premier
           arg_max(regexp_extract(replace(g.icon_path, chr(92), '/'), '([^/]+)\.png$', 1),
                   (g.icon_path ilike '%lore_passive%')::int * 1000 - g.sort_order)                     as lore_icon,
           arg_max(g.colour_hex, (g.icon_path ilike '%lore_passive%')::int * 1000 - g.sort_order)     as lore_colour
    from {{ ref('stg_dump__main_units') }} m
    join {{ ref('stg_dump__special_ability_groups_to_units_junctions') }} j
      on j.unit_key = m.unit_key or j.unit_key = m.land_unit_key
    join {{ ref('stg_dump__special_ability_groups') }} g using (ability_group_key)
    where g.show_lore_icon
    group by m.unit_key
),

mount_icons as (
    -- icône de la monture (ui/campaign ui/mounts/<icône>)
    select mounted_unit_key as unit_key,
           any_value(regexp_extract(replace(icon_name, chr(92), '/'), '([^/]+)\.png$', 1)) as mount_icon
    from {{ ref('stg_dump__units_custom_battle_mounts') }}
    group by mounted_unit_key
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
    pt.portrait_image,
    ci.category_icon,
    lg.lore_icon,
    lg.lore_colour,
    mi.mount_icon,
    coalesce(ci.is_renown, false)                                      as is_renown,   -- Régiment de Renom (bandeau de carte dédié)
    -- image à afficher : la carte du jeu, sauf carte générique « placeholder » -> portrait du personnage
    case when img.unit_card in ('placeholder', 'a_character_placeholder') then 'portrait' else 'card' end as image_source,
    o.patch
from options o
join cards_with_mounts c using (card_id)
left join {{ ref('int_unit_card_images') }} img using (unit_key)
left join flying f using (unit_key)
left join portraits pt using (unit_key)
left join category_icons ci using (unit_key)
left join lore_groups lg using (unit_key)
left join mount_icons mi using (unit_key)
