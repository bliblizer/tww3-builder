-- Échoue si un modèle de staging n'a pas le même nombre de lignes que le fichier brut (manifest).
with staged as (
    select 'db/units_custom_battle_permissions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__units_custom_battle_permissions') }}
    union all
    select 'db/custom_battle_factions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__custom_battle_factions') }}
    union all
    select 'db/factions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__factions') }}
    union all
    select 'db/cultures_subcultures_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__cultures_subcultures') }}
    union all
    select 'db/main_units_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__main_units') }}
    union all
    select 'db/ui_unit_group_parents_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ui_unit_group_parents') }}
    union all
    select 'db/ui_unit_groupings_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ui_unit_groupings') }}
    union all
    select 'db/units_custom_battle_mounts_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__units_custom_battle_mounts') }}
    union all
    select 'db/units_custom_battle_types_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__units_custom_battle_types') }}
    union all
    select 'db/units_custom_battle_types_to_factions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__units_custom_battle_types_to_factions') }}
    union all
    select 'db/units_custom_battle_type_categories_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__units_custom_battle_type_categories') }}
    union all
    select 'db/unit_set_to_mp_unit_caps_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }}
    union all
    select 'db/unit_set_to_unit_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_set_to_unit_junctions') }}
    union all
    select 'db/mp_budgets_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__mp_budgets') }}
    union all
    select 'db/battle_unit_caps_for_team_sizes_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__battle_unit_caps_for_team_sizes') }}
    union all
    select 'db/unit_stats_land_experience_bonuses_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_stats_land_experience_bonuses') }}
    union all
    select 'db/agent_subtypes_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__agent_subtypes') }}
    union all
    select 'db/agent_subtype_subculture_overrides_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__agent_subtype_subculture_overrides') }}
    union all
    select 'db/special_ability_groups_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__special_ability_groups') }}
    union all
    select 'db/special_ability_groups_to_units_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__special_ability_groups_to_units_junctions') }}
    union all
    select 'db/special_ability_groups_to_unit_abilities_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__special_ability_groups_to_unit_abilities_junctions') }}
    union all
    select 'db/unit_abilities_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_abilities') }}
    union all
    select 'db/land_units_to_unit_abilites_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__land_units_to_unit_abilites_junctions') }}
    union all
    select 'db/ancillaries_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ancillaries') }}
    union all
    select 'db/ancillaries_included_agent_subtypes_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ancillaries_included_agent_subtypes') }}
    union all
    select 'db/ancillary_to_included_agents_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ancillary_to_included_agents') }}
    union all
    select 'db/ancillaries_categories_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ancillaries_categories') }}
    union all
    select 'db/ancillaries_categories_agent_subtype_override_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ancillaries_categories_agent_subtype_override_junctions') }}
    union all
    select 'db/ui_unit_bullet_point_unit_overrides_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ui_unit_bullet_point_unit_overrides') }}
    union all
    select 'db/ui_unit_bullet_point_enums_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ui_unit_bullet_point_enums') }}
    union all
    select 'text/db/land_units__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__land_units') }}
    union all
    select 'text/db/agent_subtypes__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__agent_subtypes') }}
    union all
    select 'text/db/factions__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__factions') }}
    union all
    select 'text/db/cultures_subcultures__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__cultures_subcultures') }}
    union all
    select 'text/db/ui_unit_group_parents__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__ui_unit_group_parents') }}
    union all
    select 'text/db/ui_unit_groupings__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__ui_unit_groupings') }}
    union all
    select 'text/db/units_custom_battle_mounts__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__units_custom_battle_mounts') }}
    union all
    select 'text/db/units_custom_battle_types__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__units_custom_battle_types') }}
    union all
    select 'text/db/unit_set_to_mp_unit_caps__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__unit_set_to_mp_unit_caps') }}
    union all
    select 'text/db/unit_abilities__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__unit_abilities') }}
    union all
    select 'text/db/special_ability_groups__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__special_ability_groups') }}
    union all
    select 'text/db/ancillaries__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__ancillaries') }}
    union all
    select 'text/db/ui_unit_bullet_point_enums__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__ui_unit_bullet_point_enums') }}
    union all
    select 'db/unit_variants_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_variants') }}
    union all
    select 'db/character_skill_node_sets_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__character_skill_node_sets') }}
    union all
    select 'db/character_skill_node_set_items_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__character_skill_node_set_items') }}
    union all
    select 'db/character_skill_nodes_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__character_skill_nodes') }}
    union all
    select 'db/character_skill_level_to_effects_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__character_skill_level_to_effects_junctions') }}
    union all
    select 'db/effect_bonus_value_unit_ability_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__effect_bonus_value_unit_ability_junctions') }}
    union all
    select 'db/unit_special_abilities_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_special_abilities') }}
    union all
    select 'db/ancillary_uniqueness_groupings_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__ancillary_uniqueness_groupings') }}
    union all
    select 'text/db/units_custom_battle_type_categories__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__units_custom_battle_type_categories') }}
    union all
    select 'db/land_units_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__land_units') }}
    union all
    select 'db/battle_entities_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__battle_entities') }}
    union all
    select 'db/mounts_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__mounts') }}
    union all
    select 'db/battle_set_piece_armies_characters_items_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__battle_set_piece_armies_characters_items') }}
    union all
    select 'db/unit_armour_types_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_armour_types') }}
    union all
    select 'db/unit_shield_types_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_shield_types') }}
    union all
    select 'db/melee_weapons_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__melee_weapons') }}
    union all
    select 'db/missile_weapons_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__missile_weapons') }}
    union all
    select 'db/projectiles_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__projectiles') }}
    union all
    select 'db/projectiles_explosions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__projectiles_explosions') }}
    union all
    select 'db/unit_attributes_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_attributes') }}
    union all
    select 'db/unit_attributes_to_groups_junctions_tables/data__.tsv' as path, count(*) as n from {{ ref('stg_dump__unit_attributes_to_groups_junctions') }}
    union all
    select 'text/db/unit_attributes__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__unit_attributes') }}
    union all
    select 'text/db/ui_text_replacements__.loc.tsv' as path, count(*) as n from {{ ref('stg_dump_loc__ui_text_replacements') }}
),
manifest as (
    select path, cast(rows as bigint) as n
    from read_csv('{{ var("raw_root") }}/{{ var("patch") }}/_manifest.csv', header=true, all_varchar=true)
    where rows is not null and rows <> ''
)
select m.path, m.n as rows_manifest, s.n as rows_staged
from manifest m full outer join staged s using (path)
where m.n is distinct from s.n
