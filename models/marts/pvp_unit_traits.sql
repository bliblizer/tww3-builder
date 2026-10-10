-- Capacités innées (non sélectionnables) et attributs des unités jouables, affichés dans le panneau de gauche.
-- Grain : 1 ligne par unité x élément. kind : 'ability' (capacité innée, ex. Frenzy) | 'attribute' (ex. Hide (forest)).
with units as (select distinct unit_key from {{ ref('pvp_roster_options') }}),
texts as (select loc_key, resolved_text from {{ ref('stg_loc_texts') }}),
abilities as (
    select distinct u.unit_key, 'ability' as kind, j.ability_key as trait_key,
           coalesce(t.resolved_text, j.ability_key) as trait_name, a.icon_name
    from units u
    join {{ ref('stg_dump__main_units') }} m using (unit_key)
    join {{ ref('stg_dump__land_units_to_unit_abilites_junctions') }} j using (land_unit_key)
    join {{ ref('stg_dump__unit_abilities') }} a using (ability_key)
    left join texts t on t.loc_key = 'unit_abilities_onscreen_name_' || j.ability_key
    where not a.is_unit_upgrade and not coalesce(a.is_hidden_in_ui, false)
),
attributes as (
    select distinct u.unit_key, 'attribute', ag.attribute_key,
           -- texte du jeu « Nom||Description » : on garde le nom
           coalesce(nullif(split_part(t.resolved_text, '||', 1), ''), ag.attribute_key), null
    from units u
    join {{ ref('stg_dump__main_units') }} m using (unit_key)
    join {{ ref('stg_dump__land_units') }} lu using (land_unit_key)
    join {{ ref('stg_dump__unit_attributes_to_groups_junctions') }} ag on ag.attribute_group = lu.attribute_group
    left join texts t on t.loc_key = 'unit_attributes_bullet_text_' || ag.attribute_key
)
select *, '{{ var("patch") }}' as patch from abilities
union all
select *, '{{ var("patch") }}' from attributes
