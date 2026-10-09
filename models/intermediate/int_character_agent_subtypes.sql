-- Type de personnage (agent subtype) de chaque option de personnage (lord ou héros) du builder.
-- Grain : 1 ligne par race x unité de caste lord ou hero.
-- Le type de personnage donne l'arbre de compétences (sorts, capacités) et les objets légendaires.
--
-- Lien (hypothèse, par ordre de priorité) :
--   1. associated_unit_override du type de personnage (ou de sa surcharge par sous-culture) = la clé de l'unité ;
--   2. idem avec la clé sans suffixe de version multijoueur (_mp, _custom_battle_0) : ex. neferata_mp -> neferata ;
--   3. sinon le type d'une autre option de la même carte, de la même variante à pied (autre monture du même personnage).

with chars as (
    select race_key, unit_key, card_id, caste_key
    from {{ ref('int_unit_cards') }}
    where caste_key in ('lord', 'hero')
),

direct_links as (
    select unit_key, agent_subtype_key from {{ ref('stg_dump__agent_subtypes') }} where unit_key is not null
    union
    select unit_key, agent_subtype_key from {{ ref('stg_dump__agent_subtype_subculture_overrides') }} where unit_key is not null
),

labels as (
    select unit_key, foot_unit_key from {{ ref('int_unit_option_labels') }}
),

by_key as (
    select c.race_key, c.unit_key, c.card_id, c.caste_key, min(d.agent_subtype_key) as agent_subtype_key
    from chars c left join direct_links d using (unit_key)
    group by c.race_key, c.unit_key, c.card_id, c.caste_key
),

by_key_without_suffix as (
    select b.race_key, b.unit_key, min(d.agent_subtype_key) as agent_subtype_key
    from by_key b
    join direct_links d on d.unit_key = regexp_replace(b.unit_key, '(_mp|_custom_battle_0)$', '')
    where b.agent_subtype_key is null
    group by b.race_key, b.unit_key
),

step2 as (
    select b.race_key, b.unit_key, b.card_id, b.caste_key,
           coalesce(b.agent_subtype_key, s.agent_subtype_key) as agent_subtype_key,
           case when b.agent_subtype_key is not null then 'clé de l''unité'
                when s.agent_subtype_key is not null then 'clé sans suffixe multijoueur' end as match_method
    from by_key b
    left join by_key_without_suffix s using (race_key, unit_key)
),

same_character as (
    -- même personnage sur une autre monture : on reprend le type de sa version à pied ou d'une autre monture
    select s.race_key, s.unit_key, min(o.agent_subtype_key) as agent_subtype_key
    from step2 s
    left join labels ls on ls.unit_key = s.unit_key
    join labels lo on lo.foot_unit_key = coalesce(ls.foot_unit_key, s.unit_key)
    join step2 o on o.race_key = s.race_key and o.unit_key = lo.unit_key and o.agent_subtype_key is not null
    where s.agent_subtype_key is null
    group by s.race_key, s.unit_key
)

select
    s.race_key, s.unit_key, s.card_id, s.caste_key,
    coalesce(s.agent_subtype_key, m.agent_subtype_key)                                        as agent_subtype_key,
    coalesce(s.match_method, case when m.agent_subtype_key is not null then 'même personnage, autre monture' end) as match_method,
    '{{ var("patch") }}'                                                                       as patch
from step2 s
left join same_character m using (race_key, unit_key)
