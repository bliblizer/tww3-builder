{{ config(severity = 'warn') }}
-- Avertissement : plafonds liés à un personnage (character_name) qu'on ne sait pas rattacher à une carte du builder.
-- Ils sont ignorés par le builder. Au patch 9.0.4 : 1 ligne (wh_main_vmp_cha_vampire_lord_0, Undead Legions), les autres sont
-- résolus par la table des personnages de bataille (battle_set_piece_armies_characters : nom -> unité).
select race_key, unit_set_key, character_name, cap
from {{ ref('int_cap_group_overrides') }}
where general_card_id is null
