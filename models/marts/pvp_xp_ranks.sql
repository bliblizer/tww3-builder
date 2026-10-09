-- Rangs d'expérience achetables (0 à 9) et leur coût multijoueur.
-- HYPOTHÈSE (à vérifier en jeu) : prix au rang r = arrondi(prix de base x multiplicateur_r) + coût fixe_r.
select
    xp_level                          as rank,
    mp_experience_cost_multiplier     as cost_multiplier,
    mp_fixed_cost                     as fixed_cost,
    '{{ var("patch") }}'              as patch
from {{ ref('stg_dump__unit_stats_land_experience_bonuses') }}
