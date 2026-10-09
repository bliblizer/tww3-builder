-- Les variantes d'un même personnage (même carte) doivent avoir le même plafond spécial.
select race_key, unit_set_key, general_card_id, min(cap) as cap_min, max(cap) as cap_max
from {{ ref('int_cap_group_overrides') }}
where general_card_id is not null
group by all
having min(cap) <> max(cap)
