{{ config(severity = 'warn') }}
-- Avertissement : options de personnage jouables sans type de personnage (donc sans objets légendaires).
-- Au patch 9.0.4 : 5 options (Boris Todbringer « Toddy » x4, Kairos custom_battle_0), après l'ajout des personnages de
-- bataille (battle_set_piece_armies_characters) qui a résolu Arkhan, Mannfred, Nagash et le Lord of Change.
select s.race_key, s.unit_key
from {{ ref('int_character_agent_subtypes') }} s
join {{ ref('pvp_roster_options') }} o using (race_key, unit_key)
where s.agent_subtype_key is null
