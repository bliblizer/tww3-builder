{{ config(severity = 'warn') }}
-- Avertissement : plafonds liés à un personnage (character_name) qu'on ne sait pas rattacher à une carte du builder.
-- Ils sont ignorés par le builder. Au patch 9.0 : Nagash, Arkhan, Liche Priest, Vampire Lord, Mourngul (7 lignes).
select race_key, unit_set_key, character_name, cap
from {{ ref('int_cap_group_overrides') }}
where general_card_id is null
