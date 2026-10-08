-- Roster PvP : les options jouables de chaque carte (1 option = 1 clé d'unité, celle des fichiers .army_setup).
-- Grain : 1 ligne par race x unité SÉLECTIONNABLE en PvP.
-- Règle : on filtre d'abord (PvP uniquement), on calcule ensuite (libellé « On foot » selon les seules options PvP).

with options as (
    select * from {{ ref('int_unit_cards') }}
    where is_selectable_pvp
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
    case when c.has_mounts then coalesce(o.mount_name, 'On foot') end   as mount,
    o.is_general_unit_pvp                                              as can_be_general,
    o.multiplayer_cost,
    o.faction_keys_pvp                                                 as faction_keys,
    img.unit_card,
    o.patch
from options o
join cards_with_mounts c using (card_id)
left join {{ ref('int_unit_card_images') }} img using (unit_key)
