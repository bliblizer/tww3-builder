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
--   objets             = liste de bataille personnalisée de l'unité (battle_set_piece_armies_characters_items),
--                        vérifiée exactement sur 9 personnages (fichiers .army_setup « tout sélectionné »)
--   coûts (vérifiés en jeu) = grille par rareté, la même pour capacités, objets et sorts :
--                        common 100 / uncommon 150 / rare 200 / legendary 200 ; pour les objets, la rareté vient de
--                        uniqueness_score (groupes ancillary_uniqueness_groupings).
--                        Sorts : prix de rareté avant la remise dégressive calculée dans le builder (voir pvp_character_upgrades).

with chars as (
    select c.race_key, c.unit_key, c.agent_subtype_key, m.land_unit_key
    from {{ ref('int_character_agent_subtypes') }} c
    join {{ ref('stg_dump__main_units') }} m using (unit_key)
),

abilities as (
    select a.ability_key, a.is_hidden_in_ui, a.is_unit_upgrade, a.uniqueness, a.icon_name, coalesce(s.mana_cost, 0) as mana_cost
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

item_lists as (
    -- liste d'objets de bataille personnalisée, par clé d'unité (table au nom trompeur, vérifiée en jeu sur 9 personnages)
    select unit_key as list_unit_key, ancillary_key
    from {{ ref('stg_dump__battle_set_piece_armies_characters_items') }}
),

agent_units as (
    select agent_subtype_key, unit_key from {{ ref('stg_dump__agent_subtypes') }} where unit_key is not null
    union
    select agent_subtype_key, unit_key from {{ ref('stg_dump__agent_subtype_subculture_overrides') }} where unit_key is not null
),

item_source as (
    -- clé de la liste d'objets à utiliser pour chaque option, par ordre de priorité :
    --   1. la clé de l'unité  2. sa version à pied  3. l'unité de son type de personnage
    --   4. une liste dont la clé commence par celle de l'unité du type de personnage (ex. bloab -> bloab_rotspawned),
    --      hors batailles de quête (_qb_)
    select
        c.race_key, c.unit_key,
        coalesce(
            (select min(l.list_unit_key) from item_lists l where l.list_unit_key = c.unit_key),
            (select min(l.list_unit_key) from item_lists l join {{ ref('int_unit_option_labels') }} ol on ol.foot_unit_key = l.list_unit_key
              where ol.unit_key = c.unit_key),
            (select min(l.list_unit_key) from item_lists l join agent_units a on a.unit_key = l.list_unit_key
              where a.agent_subtype_key = c.agent_subtype_key),
            (select min(l.list_unit_key) from item_lists l join agent_units a on starts_with(l.list_unit_key, a.unit_key || '_')
              where a.agent_subtype_key = c.agent_subtype_key and l.list_unit_key not like '%\_qb\_%' escape '\')
        ) as list_unit_key
    from chars c
),

items as (
    select distinct src.race_key, src.unit_key, an.ancillary_key, an.category, an.uniqueness_score
    from item_source src
    join item_lists l using (list_unit_key)
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
    case rg.ui_state when 'common' then 100 when 'uncommon' then 150 when 'rare' then 200 when 'legendary' then 200 end as cost,
    case when rg.ui_state is null then 'inconnu (rareté absente)'
         when a.mana_cost > 0 then 'rareté, avant remise dégressive des sorts'
         else 'rareté (vérifié en jeu)' end                                            as cost_status,
    aa.source,
    null                                                                                as item_category,
    rg.ui_state                                                                         as rarity_state,
    rg.col_hex                                                                          as rarity_hex,
    a.icon_name                                                                         as icon_name,   -- ui/battle ui/ability_icons/<icon_name>
    '{{ var("patch") }}'                                                                as patch
from all_abilities aa
join abilities a using (ability_key)
left join texts t on t.loc_key = 'unit_abilities_onscreen_name_' || aa.ability_key
left join rarity_groups rg on rg.uniqueness_group_key = a.uniqueness
where not coalesce(a.is_hidden_in_ui, false)

union all

select
    i.race_key, i.unit_key, 'item', i.ancillary_key, t.resolved_text, rg.ui_state, null,
    case rg.ui_state when 'common' then 100 when 'uncommon' then 150 when 'rare' then 200 when 'legendary' then 200 end,
    case when rg.ui_state is null then 'inconnu (rareté absente)' else 'rareté (vérifié en jeu)' end, 'liste d''objets du personnage',
    i.category, rg.ui_state, rg.col_hex, null, '{{ var("patch") }}'
from items i
left join texts t on t.loc_key = 'ancillaries_onscreen_name_' || i.ancillary_key
left join rarity_groups rg on i.uniqueness_score between rg.uniqueness_min and rg.uniqueness_max
