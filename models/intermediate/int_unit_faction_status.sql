-- Statut de chaque unité dans le builder de bataille, faction par faction.
-- Grain : 1 ligne par couple faction x unité présent dans units_custom_battle_permissions
--         (une unité absente de cette table n'apparaît jamais dans le builder).
--
-- Règles (déduites des données et de l'écran custom_battle.twui.xml, validées en partie en jeu) :
--   visible          = présente dans les permissions de la faction
--   bloquée          = campaign_exclusive = true  OU  membre d'un groupe de caps à 0
--                      qui s'applique à la race de la faction (cap global ou cap de cette sous-culture)
--   sélectionnable   = visible et non bloquée

with permissions as (
    select faction_key, unit_key, general_unit, campaign_exclusive
    from {{ ref('stg_dump__units_custom_battle_permissions') }}
),

races as (
    select faction_key, race_key
    from {{ ref('int_faction_race') }}
),

units as (
    select unit_key, caste_key, multiplayer_cost, ui_group_key
    from {{ ref('stg_dump__main_units') }}
),

ui_groups as (
    select ui_group_key, tab_key
    from {{ ref('stg_dump__ui_unit_groupings') }}
),

zero_caps as (
    -- groupes de caps à 0 = interdits ; subculture_key vide = s'applique à toutes les races
    select unit_set_key, subculture_key
    from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }}
    where cap = 0
),

zero_cap_members as (
    -- membres des groupes à 0 : désignés par unité ou par caste (aucune exclusion utilisée, voir tests)
    select j.unit_key, null as caste_key, z.unit_set_key, z.subculture_key
    from {{ ref('stg_dump__unit_set_to_unit_junctions') }} j
    join zero_caps z using (unit_set_key)
    where j.unit_key is not null
    union all
    select null, j.caste_key, z.unit_set_key, z.subculture_key
    from {{ ref('stg_dump__unit_set_to_unit_junctions') }} j
    join zero_caps z using (unit_set_key)
    where j.unit_key is null and j.caste_key is not null
),

blocking as (
    -- pour chaque couple faction x unité : liste des groupes à 0 qui s'appliquent
    select
        p.faction_key,
        p.unit_key,
        string_agg(distinct m.unit_set_key, ' | ' order by m.unit_set_key) as blocking_cap_sets
    from permissions p
    join races r   using (faction_key)
    join units u   using (unit_key)
    join zero_cap_members m
      on (m.unit_key = p.unit_key or m.caste_key = u.caste_key)
     and (m.subculture_key is null or m.subculture_key = r.race_key)
    group by p.faction_key, p.unit_key
)

select
    p.faction_key,
    r.race_key,
    p.unit_key,
    p.general_unit                                          as is_general_unit,
    true                                                    as is_visible_in_builder,
    p.campaign_exclusive                                    as is_campaign_exclusive,
    b.blocking_cap_sets,
    b.blocking_cap_sets is not null                         as is_blocked_by_zero_cap,
    not p.campaign_exclusive and b.blocking_cap_sets is null as is_selectable_pvp,
    case
        when p.campaign_exclusive and b.blocking_cap_sets is not null then 'campaign_exclusive + zero_cap'
        when p.campaign_exclusive                                    then 'campaign_exclusive'
        when b.blocking_cap_sets is not null                         then 'zero_cap'
    end                                                     as blocking_reason,
    u.multiplayer_cost,
    u.caste_key,
    u.ui_group_key,
    g.tab_key,
    '{{ var("patch") }}'                                    as patch
from permissions p
left join races r     using (faction_key)
left join units u     using (unit_key)
left join ui_groups g on g.ui_group_key = u.ui_group_key
left join blocking b  on b.faction_key = p.faction_key and b.unit_key = p.unit_key
