-- Groupes de capacités (domaines de magie…)
-- Source : db/special_ability_groups_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "ability_group"                                         as ability_group_key,
    "icon_path"                                             as icon_path,
    cast("special_edition_mask" as bigint)                  as special_edition_mask,
    cast("sort_order" as bigint)                            as sort_order,
    cast("is_naval" as boolean)                             as is_naval,
    "button_name"                                           as button_name,
    "sound_event"                                           as sound_event,
    cast("is_composite_group" as boolean)                   as is_composite_group,
    cast("unique_id" as bigint)                             as unique_id,
    "sound_switch"                                          as sound_switch,
    cast("show_lore_icon" as boolean)                       as show_lore_icon,
    "colour_hex"                                            as colour_hex,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/special_ability_groups_tables/data__.tsv') }}
