-- Non-régression : la réécriture SQL doit reproduire exactement le statut calculé par les scripts Python de la V0.
-- Renvoie chaque couple faction x unité qui diffère (ou n'existe que d'un côté).
with new as (
    select faction_key, unit_key, race_key, is_general_unit, is_campaign_exclusive,
           coalesce(blocking_cap_sets, '') as blocking_cap_sets, is_selectable_pvp, multiplayer_cost, ui_group_key, tab_key
    from {{ ref('int_unit_faction_status') }}
),
old as (
    select faction_key, unit_key, subculture_key as race_key, general_unit as is_general_unit, is_campaign_exclusive,
           coalesce(blocking_cap_sets, '') as blocking_cap_sets, is_selectable_pvp, multiplayer_cost, ui_group_key,
           ui_group_parent_key as tab_key
    from {{ ref('ref_v0_unit_faction_status') }}
)
select *
from (select 'nouveau' as cote, * from (select * from new except select * from old))
union all
select *
from (select 'référence v0' as cote, * from (select * from old except select * from new))
