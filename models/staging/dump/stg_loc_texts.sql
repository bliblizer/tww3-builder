-- Tous les textes du jeu en une table, avec les renvois vers d'autres textes résolus.
-- Le jeu écrit un renvoi sous la forme : accolade accolade tr:<clé> accolade accolade.
-- Un renvoi vers une clé absente des fichiers chargés reste tel quel (has_unresolved_reference = true).
{% set ref_open = "'{' || '{tr:'" %}
{% set ref_close = "'}' || '}'" %}
with recursive all_loc as (
    select loc_key, text, 'agent_subtypes' as loc_table from {{ ref('stg_dump_loc__agent_subtypes') }}
    union all
    select loc_key, text, 'ancillaries' as loc_table from {{ ref('stg_dump_loc__ancillaries') }}
    union all
    select loc_key, text, 'cultures_subcultures' as loc_table from {{ ref('stg_dump_loc__cultures_subcultures') }}
    union all
    select loc_key, text, 'factions' as loc_table from {{ ref('stg_dump_loc__factions') }}
    union all
    select loc_key, text, 'land_units' as loc_table from {{ ref('stg_dump_loc__land_units') }}
    union all
    select loc_key, text, 'special_ability_groups' as loc_table from {{ ref('stg_dump_loc__special_ability_groups') }}
    union all
    select loc_key, text, 'ui_unit_bullet_point_enums' as loc_table from {{ ref('stg_dump_loc__ui_unit_bullet_point_enums') }}
    union all
    select loc_key, text, 'ui_unit_group_parents' as loc_table from {{ ref('stg_dump_loc__ui_unit_group_parents') }}
    union all
    select loc_key, text, 'ui_unit_groupings' as loc_table from {{ ref('stg_dump_loc__ui_unit_groupings') }}
    union all
    select loc_key, text, 'unit_abilities' as loc_table from {{ ref('stg_dump_loc__unit_abilities') }}
    union all
    select loc_key, text, 'unit_set_to_mp_unit_caps' as loc_table from {{ ref('stg_dump_loc__unit_set_to_mp_unit_caps') }}
    union all
    select loc_key, text, 'units_custom_battle_mounts' as loc_table from {{ ref('stg_dump_loc__units_custom_battle_mounts') }}
    union all
    select loc_key, text, 'units_custom_battle_types' as loc_table from {{ ref('stg_dump_loc__units_custom_battle_types') }}
    union all
    select loc_key, text, 'units_custom_battle_type_categories' as loc_table from {{ ref('stg_dump_loc__units_custom_battle_type_categories') }}
),
resolved(loc_key, loc_table, text, depth) as (
    select loc_key, loc_table, text, 0 from all_loc
    union all
    select r.loc_key, r.loc_table,
           replace(r.text, {{ ref_open }} || target.loc_key || {{ ref_close }}, coalesce(target.text, '')),
           r.depth + 1
    from resolved r
    join all_loc target
      on target.loc_key = regexp_extract(r.text, '[{][{]tr:([^}]+)[}][}]', 1)
    where r.depth < 10
)
select
    loc_key,
    loc_table,
    arg_max(text, depth)                                   as resolved_text,
    max(depth) > 0                                         as had_reference,
    contains(coalesce(arg_max(text, depth), ''), {{ ref_open }})  as has_unresolved_reference,
    '{{ var("patch") }}'                                   as patch
from resolved
group by loc_key, loc_table
