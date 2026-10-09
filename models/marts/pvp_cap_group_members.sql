-- Appartenance des unités jouables aux groupes de caps (clé d'unité = clé des options du roster).
-- Grain : 1 ligne par race x groupe x unité.
select m.race_key, m.unit_set_key, m.unit_key, m.patch
from {{ ref('int_cap_group_members') }} m
join {{ ref('int_cap_groups') }} g using (race_key, unit_set_key)
