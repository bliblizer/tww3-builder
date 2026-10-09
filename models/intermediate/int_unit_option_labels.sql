-- Libellés d'options de chaque unité qui est une monture ou une variante (domaine de magie, marque…).
-- Grain : 1 ligne par unité présente dans les tables de montures ou de variantes du builder.
--   foot_unit_key : version à pied (on remonte la chaîne des montures)
--   mount_name    : nom de la monture si l'unité est une version montée
--   lore / mark / forest_spirit / other_variant : libellés de variante de la version à pied
-- Les libellés ne dépendent pas de la race ; c'est int_unit_cards qui décide s'ils s'appliquent.

with recursive mounts as (
    select base_unit_key, mounted_unit_key
    from {{ ref('stg_dump__units_custom_battle_mounts') }}
),

types as (
    select base_unit_key, alternate_unit_key, type_category_key
    from {{ ref('stg_dump__units_custom_battle_types') }}
),

texts as (
    select loc_key, resolved_text from {{ ref('stg_loc_texts') }}
),

all_units as (
    select base_unit_key as unit_key from mounts union
    select mounted_unit_key from mounts union
    select base_unit_key from types union
    select alternate_unit_key from types
),

-- remonte la chaîne monture -> base jusqu'à la version à pied
foot_chain(unit_key, current_key, depth) as (
    select unit_key, unit_key, 0 from all_units
    union all
    select f.unit_key, m.base_unit_key, f.depth + 1
    from foot_chain f
    join mounts m on m.mounted_unit_key = f.current_key
    where f.depth < 10
),

foot as (
    select unit_key, arg_max(current_key, depth) as foot_unit_key
    from foot_chain group by unit_key
),

mount_names as (
    select m.mounted_unit_key as unit_key, m.base_unit_key as mount_base_unit_key, t.resolved_text as mount_name
    from mounts m
    left join texts t on t.loc_key = 'units_custom_battle_mounts_mount_name_' || m.base_unit_key || m.mounted_unit_key
),

variant_labels as (
    -- libellé du type ; vide pour les domaines de magie -> dernière parenthèse du nom de l'unité, sinon son nom
    select
        ty.alternate_unit_key as unit_key,
        case ty.type_category_key
            when 'type_spell_lore'    then 'lore'
            when 'type_mark'          then 'mark'
            when 'type_forest_spirit' then 'forest_spirit'
            else 'other_variant'
        end as category,
        coalesce(
            nullif(tn.resolved_text, ''),
            list_last(regexp_extract_all(un.resolved_text, '\(([^)]+)\)', 1)),
            un.resolved_text
        ) as label
    from types ty
    left join texts tn on tn.loc_key = 'units_custom_battle_types_type_name_' || ty.base_unit_key || ty.alternate_unit_key || ty.type_category_key
    left join texts un on un.loc_key = 'land_units_onscreen_name_' || ty.alternate_unit_key
),

variants as (
    select
        unit_key,
        any_value(label) filter (where category = 'lore')          as lore,
        any_value(label) filter (where category = 'mark')          as mark,
        any_value(label) filter (where category = 'forest_spirit') as forest_spirit,
        any_value(label) filter (where category = 'other_variant') as other_variant
    from variant_labels
    group by unit_key
)

select
    a.unit_key,
    f.foot_unit_key,
    mn.mount_base_unit_key,
    mn.mount_name,
    v.lore,
    v.mark,
    v.forest_spirit,
    v.other_variant,
    '{{ var("patch") }}' as patch
from all_units a
join foot f using (unit_key)
left join mount_names mn using (unit_key)
left join variants v on v.unit_key = f.foot_unit_key
