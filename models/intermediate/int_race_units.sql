-- Unités du builder, vues au niveau de la race (on fusionne les factions d'une même race).
-- Grain : 1 ligne par race x unité.
-- Une unité est sélectionnable pour la race si elle l'est pour au moins une faction de cette race.

with status as (
    select * from {{ ref('int_unit_faction_status') }}
),

units as (
    select unit_key, land_unit_key from {{ ref('stg_dump__main_units') }}
),

texts as (
    select loc_key, resolved_text from {{ ref('stg_loc_texts') }}
)

select
    s.race_key,
    s.unit_key,
    n.resolved_text                                                         as unit_name,
    bool_or(s.is_selectable_pvp)                                            as is_selectable_pvp,
    bool_or(s.is_general_unit)                                              as is_general_unit,
    bool_or(s.is_general_unit and s.is_selectable_pvp)                      as is_general_unit_pvp,
    any_value(s.multiplayer_cost)                                           as multiplayer_cost,
    any_value(s.caste_key)                                                  as caste_key,
    any_value(s.ui_group_key)                                               as ui_group_key,
    any_value(s.tab_key)                                                    as tab_key,
    string_agg(s.faction_key, ' | ' order by s.faction_key)                 as faction_keys,
    string_agg(s.faction_key, ' | ' order by s.faction_key)
        filter (where s.is_selectable_pvp)                                  as faction_keys_pvp,
    string_agg(distinct s.blocking_reason, ' | ')                           as blocking_reasons,
    count(distinct s.multiplayer_cost)                                      as nb_distinct_costs,
    '{{ var("patch") }}'                                                    as patch
from status s
join units u using (unit_key)
left join texts n on n.loc_key = 'land_units_onscreen_name_' || u.land_unit_key
group by s.race_key, s.unit_key, n.resolved_text
