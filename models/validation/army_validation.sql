-- Validation d'une armée PvP : spécification exécutable des règles appliquées par le builder (app/template.html).
-- Appliquée ici aux armées de test (seeds/tests/test_armies.csv) ; le test assert_army_validation_matches_expectations
-- compare le verdict à l'attendu. Toute règle modifiée ici doit l'être aussi dans le builder, et inversement.
--
-- Codes d'erreur :
--   NO_GENERAL             la première unité n'est pas un lord pouvant être général pour la race
--   MULTIPLE_LORDS         plus d'un lord dans l'armée (en jeu, choisir un lord remplace le précédent)
--   UNIT_NOT_AVAILABLE     une unité n'est pas jouable en PvP pour la race
--   TOO_MANY_UNITS         plus d'unités que le maximum (20)
--   OVER_BUDGET            coût total (prix de base) supérieur au budget (12 400)
--   CAP_EXCEEDED:<groupe>  plus d'unités d'un groupe que son plafond ; plafond effectif = max(défaut, plafonds spéciaux
--                          des personnages présents dans l'armée, général ou héros)

with army as (
    select * from {{ ref('test_armies') }}
),

rules as (
    select * from {{ ref('pvp_army_rules') }}
),

units as (
    select a.army_id, a.race_key, a.slot, a.unit_key, o.card_id, o.can_be_general, o.is_lord, o.multiplayer_cost,
           o.unit_key is not null as is_available
    from army a
    left join {{ ref('pvp_roster_options') }} o using (race_key, unit_key)
),

general as (
    select army_id, coalesce(is_lord and can_be_general, false) as is_general
    from units where slot = 1
),

overrides_present as (
    -- plafonds spéciaux apportés par les personnages présents dans l'armée (général ou héros)
    select distinct u.army_id, ov.unit_set_key, ov.cap
    from units u
    join {{ ref('pvp_cap_overrides') }} ov on ov.race_key = u.race_key and ov.general_card_id = u.card_id
),

cap_counts as (
    select u.army_id, m.unit_set_key, count(*) as nb_units,
           greatest(max(g.default_cap), coalesce((select max(op.cap) from overrides_present op
                                                   where op.army_id = u.army_id and op.unit_set_key = m.unit_set_key), 0)) as effective_cap
    from units u
    join {{ ref('pvp_cap_group_members') }} m on m.race_key = u.race_key and m.unit_key = u.unit_key
    join {{ ref('pvp_cap_groups') }} g on g.race_key = m.race_key and g.unit_set_key = m.unit_set_key
    group by u.army_id, m.unit_set_key
),

errors as (
    select army_id, 'NO_GENERAL' as error from general where not is_general
    union all
    select army_id, 'MULTIPLE_LORDS' from units group by army_id having count(*) filter (where is_lord) > 1
    union all
    select distinct army_id, 'UNIT_NOT_AVAILABLE' from units where not is_available
    union all
    select army_id, 'TOO_MANY_UNITS' from units group by army_id having count(*) > (select max_units from rules)
    union all
    select army_id, 'OVER_BUDGET' from units group by army_id having sum(multiplayer_cost) > (select budget from rules)
    union all
    select army_id, 'CAP_EXCEEDED:' || unit_set_key from cap_counts where nb_units > effective_cap
)

select
    a.army_id,
    any_value(a.race_key)                                                   as race_key,
    count(distinct a.slot)                                                  as nb_units,
    (select sum(multiplayer_cost) from units u where u.army_id = a.army_id) as total_cost,
    coalesce((select string_agg(distinct e.error, '|' order by e.error) from errors e where e.army_id = a.army_id), '') as errors,
    not exists (select 1 from errors e where e.army_id = a.army_id)        as is_valid
from army a
group by a.army_id
