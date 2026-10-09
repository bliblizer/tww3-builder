-- Éléments de personnalisation proposés pour chaque option de personnage : sorts, capacités, objets.
-- Grain : 1 ligne par race x unité x élément.
--
-- HYPOTHÈSES (à vérifier avec des fichiers .army_setup « Tout sélectionner » extraits du jeu) :
--   sorts et capacités = domaines de magie rattachés à l'unité (special_ability_groups : sorts + passif du domaine)
--                        + capacités propres de l'unité marquées « amélioration » (is_unit_upgrade)
--                        (vérifié sur le panneau de Neferata : 6 sorts et 6 capacités identiques, coûts conformes).
--                        L'arbre de compétences (skill_tree, gardé ci-dessous pour référence) ajoute des versions
--                        « Upgraded » et des capacités absentes du panneau : il n'est PAS utilisé.
--                        ; sort = consomme du mana (règle de l'écran du jeu) ; capacités cachées exclues
--   objets             = objets réservés au type de personnage (ancillaries_included_agent_subtypes),
--                        hors suiveurs (follower) et formes (form)
--   coûts              = capacités : rareté common 100 / uncommon 150 / rare 200 ; objets : uniqueness_score ;
--                        sorts : inconnu (formule dégressive à venir)

with chars as (
    select c.race_key, c.unit_key, c.agent_subtype_key, m.land_unit_key
    from {{ ref('int_character_agent_subtypes') }} c
    join {{ ref('stg_dump__main_units') }} m using (unit_key)
),

abilities as (
    select a.ability_key, a.is_hidden_in_ui, a.is_unit_upgrade, a.uniqueness, coalesce(s.mana_cost, 0) as mana_cost
    from {{ ref('stg_dump__unit_abilities') }} a
    left join {{ ref('stg_dump__unit_special_abilities') }} s using (ability_key)
),

skill_tree as (
    select distinct c.race_key, c.unit_key, e.ability_key, 'arbre de compétences' as source
    from chars c
    join {{ ref('stg_dump__character_skill_node_sets') }} ns on ns.agent_subtype_key = c.agent_subtype_key
    join {{ ref('stg_dump__character_skill_node_set_items') }} ni on ni.node_set_key = ns.node_set_key
    join {{ ref('stg_dump__character_skill_nodes') }} n on n.node_key = ni.node_key
    join {{ ref('stg_dump__character_skill_level_to_effects_junctions') }} se on se.skill_key = n.skill_key
    join {{ ref('stg_dump__effect_bonus_value_unit_ability_junctions') }} e on e.effect_key = se.effect_key
),

lore_groups as (
    select distinct c.race_key, c.unit_key, ga.ability_key, 'domaine de magie' as source
    from chars c
    join {{ ref('stg_dump__special_ability_groups_to_units_junctions') }} gu
      on gu.unit_key = c.unit_key or gu.unit_key = c.land_unit_key
    join {{ ref('stg_dump__special_ability_groups_to_unit_abilities_junctions') }} ga using (ability_group_key)
),

native as (
    select distinct c.race_key, c.unit_key, j.ability_key, 'capacité de l''unité' as source
    from chars c
    join {{ ref('stg_dump__land_units_to_unit_abilites_junctions') }} j on j.land_unit_key = c.land_unit_key
    join abilities a using (ability_key)
    where a.is_unit_upgrade
),

all_abilities as (
    select race_key, unit_key, ability_key, string_agg(distinct source, ' + ' order by source) as source
    from (select * from lore_groups union all select * from native)
    group by race_key, unit_key, ability_key
),

items as (
    select distinct c.race_key, c.unit_key, an.ancillary_key, an.category, an.uniqueness_score
    from chars c
    join {{ ref('stg_dump__ancillaries_included_agent_subtypes') }} ia on ia.agent_subtype_key = c.agent_subtype_key
    join {{ ref('stg_dump__ancillaries') }} an using (ancillary_key)
    where coalesce(an.category, '') not in ('follower', 'form', 'mount')   -- montures : gérées par les options de carte
),

texts as (
    select loc_key, resolved_text from {{ ref('stg_loc_texts') }}
),

rarity_groups as (
    -- groupes de rareté du jeu, avec leur couleur (col_hex) ; les objets y sont rangés par uniqueness_score
    select uniqueness_group_key, ui_state, col_hex, uniqueness_min, uniqueness_max
    from {{ ref('stg_dump__ancillary_uniqueness_groupings') }}
    where ui_state in ('common', 'uncommon', 'rare', 'legendary')
)

select
    aa.race_key, aa.unit_key,
    case when a.mana_cost > 0 then 'spell' else 'ability' end                          as upgrade_type,
    aa.ability_key                                                                      as upgrade_key,
    t.resolved_text                                                                     as upgrade_name,
    replace(a.uniqueness, 'wh_main_anc_group_', '')                                    as rarity,
    a.mana_cost,
    case when a.mana_cost > 0 then null
         else case replace(a.uniqueness, 'wh_main_anc_group_', '')
                when 'common' then 100 when 'uncommon' then 150 when 'rare' then 200 end
    end                                                                                 as cost,
    case when a.mana_cost > 0 then 'inconnu (sorts)'
         when replace(a.uniqueness, 'wh_main_anc_group_', '') in ('common', 'uncommon', 'rare') then 'hypothèse : rareté'
         else 'inconnu (rareté ' || coalesce(replace(a.uniqueness, 'wh_main_anc_group_', ''), 'absente') || ')' end as cost_status,
    aa.source,
    null                                                                                as item_category,
    rg.ui_state                                                                         as rarity_state,
    rg.col_hex                                                                          as rarity_hex,
    '{{ var("patch") }}'                                                                as patch
from all_abilities aa
join abilities a using (ability_key)
left join texts t on t.loc_key = 'unit_abilities_onscreen_name_' || aa.ability_key
left join rarity_groups rg on rg.uniqueness_group_key = a.uniqueness
where not coalesce(a.is_hidden_in_ui, false)

union all

select
    i.race_key, i.unit_key, 'item', i.ancillary_key, t.resolved_text, rg.ui_state, null,
    i.uniqueness_score, 'hypothèse : uniqueness_score', 'objet du personnage',
    i.category, rg.ui_state, rg.col_hex, '{{ var("patch") }}'
from items i
left join texts t on t.loc_key = 'ancillaries_onscreen_name_' || i.ancillary_key
left join rarity_groups rg on i.uniqueness_score between rg.uniqueness_min and rg.uniqueness_max
