-- Les prix calculés doivent correspondre aux prix relevés en jeu, à 1 pièce d'or près (formule des sorts empirique).
-- Vérifie aussi que chaque élément des relevés existe bien dans le modèle (sinon il ne serait pas compté).
select case_id, description, computed_price, expected_price, 'écart de prix' as probleme
from {{ ref('unit_price_checks') }}
where abs(computed_price - expected_price) > 1
union all
select p.case_id, p.upgrade_key, null, null, 'élément absent du modèle'
from {{ ref('test_unit_prices') }} p
where p.upgrade_key is not null
  and not exists (select 1 from {{ ref('pvp_character_upgrades') }} u
                  where u.race_key = p.race_key and u.unit_key = p.unit_key and u.upgrade_key = p.upgrade_key)
