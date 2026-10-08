-- Roster PvP : les cartes du builder (1 carte = 1 unité de base + ses options jouables).
-- Grain : 1 ligne par carte ayant au moins une option sélectionnable en PvP.
-- Toutes les colonnes calculées le sont APRÈS le filtre PvP (coûts, nombre d'options, présence d'un vrai choix).

with options as (
    select * from {{ ref('pvp_roster_options') }}
),

card_root as (
    -- nom, racine, onglet et sous-groupe de la carte (portés par l'unité racine)
    select card_id, card_name, root_unit_key, tab_key, ui_group_key
    from {{ ref('int_unit_cards') }}
    where is_root
),

tabs as (
    select tab_key, tab_order from {{ ref('stg_dump__ui_unit_group_parents') }}
),

texts as (
    select loc_key, resolved_text from {{ ref('stg_loc_texts') }}
),

races as (
    select distinct race_key, race_name from {{ ref('int_faction_race') }}
),

agg as (
    select
        race_key,
        card_id,
        count(*)                                                                as nb_options,
        count(distinct concat_ws('|', coalesce(lore, ''), coalesce(mark, ''),
                                      coalesce(forest_spirit, ''), coalesce(other_variant, ''))) > 1
                                                                                as has_variant_choice,
        count(distinct mount) > 1                                               as has_mount_choice,
        bool_or(can_be_general)                                                 as can_be_general,
        min(multiplayer_cost)                                                   as min_cost,
        max(multiplayer_cost)                                                   as max_cost
    from options
    group by race_key, card_id
)

select
    a.race_key,
    r.race_name,
    a.card_id,
    cr.card_name,
    cr.root_unit_key,
    t.tab_order,
    cr.tab_key,
    tab_name.resolved_text                as tab_name,
    cr.ui_group_key,
    group_name.resolved_text              as ui_group_name,
    a.can_be_general,
    a.nb_options,
    a.has_variant_choice,
    a.has_mount_choice,
    a.min_cost,
    a.max_cost,
    '{{ var("patch") }}'                  as patch
from agg a
join card_root cr using (card_id)
left join races r using (race_key)
left join tabs t on t.tab_key = cr.tab_key
left join texts tab_name   on tab_name.loc_key   = 'ui_unit_group_parents_onscreen_name_' || cr.tab_key
left join texts group_name on group_name.loc_key = 'ui_unit_groupings_onscreen_' || cr.ui_group_key
