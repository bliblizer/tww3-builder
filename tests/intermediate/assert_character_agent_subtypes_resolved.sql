{{ config(severity = 'warn') }}
-- Avertissement : options de personnage jouables sans type de personnage (donc sans objets légendaires).
-- Au patch 9.0 : 18 options (Arkhan, Mannfred, Nagash, Kairos, Boris Todbringer, Lord of Change).
select s.race_key, s.unit_key
from {{ ref('int_character_agent_subtypes') }} s
join {{ ref('pvp_roster_options') }} o using (race_key, unit_key)
where s.agent_subtype_key is null
