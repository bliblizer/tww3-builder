-- Prix d'une unité personnalisée : spécification exécutable de la formule appliquée par le builder (app/template.html),
-- appliquée aux prix relevés en jeu (seeds/tests/test_unit_prices.csv).
--
-- Formule (déduite de 8 relevés en jeu sur Neferata) :
--   prix = prix de base (main_units.multiplayer_cost, monture comprise dans la clé d'unité)
--        + somme des capacités et objets cochés (grille de rareté : common 100, uncommon 150, rare 200, legendary 200)
--        + sorts : arrondi inférieur de  somme( prix de rareté du k-ième sort x (1 - 0,047 x k) ),
--                  les sorts cochés étant classés du plus cher au moins cher (k = 0, 1, 2…)
--   Précision : à ±1 pièce d'or près sur les 8 relevés (formule empirique, le jeu ne stocke pas ces prix).
{% set spell_step = 0.047 %}

with cases as (
    select distinct case_id, race_key, unit_key, expected_price, description from {{ ref('test_unit_prices') }}
),

picked as (
    select p.case_id, u.upgrade_type, u.cost,
           row_number() over (partition by p.case_id, u.upgrade_type order by u.cost desc, u.upgrade_key) - 1 as k
    from {{ ref('test_unit_prices') }} p
    join {{ ref('pvp_character_upgrades') }} u
      on u.race_key = p.race_key and u.unit_key = p.unit_key and u.upgrade_key = p.upgrade_key
),

totals as (
    select case_id,
           coalesce(sum(cost) filter (where upgrade_type <> 'spell'), 0)                                   as other_cost,
           coalesce(floor(sum(cost * (1 - {{ spell_step }} * k)) filter (where upgrade_type = 'spell')), 0) as spell_cost,
           count(*) as nb_picked
    from picked group by case_id
)

select
    c.case_id, c.description, o.multiplayer_cost as base_cost,
    coalesce(t.spell_cost, 0) as spell_cost, coalesce(t.other_cost, 0) as other_cost,
    o.multiplayer_cost + coalesce(t.spell_cost, 0) + coalesce(t.other_cost, 0) as computed_price,
    c.expected_price
from cases c
join {{ ref('pvp_roster_options') }} o using (race_key, unit_key)
left join totals t using (case_id)
