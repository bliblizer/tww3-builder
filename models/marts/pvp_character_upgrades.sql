-- Personnalisation des personnages jouables en PvP : sorts, capacités et objets proposés par option (clé d'unité).
-- Grain : 1 ligne par race x unité x élément. Monture et domaine de magie = options de la carte (pvp_roster_options).
-- Règles et hypothèses de coût : voir int_character_upgrades.
select u.race_key, u.unit_key, u.upgrade_type, u.upgrade_key, coalesce(u.upgrade_name, u.upgrade_key) as upgrade_name,
       u.rarity, u.cost, u.cost_status, u.source,
       true as is_selected_by_default,   -- hypothèse : tout est coché par défaut (prix affichés en jeu = avec sorts et objets)
       u.patch
from {{ ref('int_character_upgrades') }} u
join {{ ref('pvp_roster_options') }} o using (race_key, unit_key)
