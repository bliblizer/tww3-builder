-- Plafonds qui dépendent du personnage (character_name) : ex. chez les Undead Legions, le groupe des unités
-- des Tomb Kings passe de 2 à 18 avec un Tomb King.
-- Grain : 1 ligne par race x groupe x carte de personnage.
--
-- Règle (validée en jeu) : le plafond spécial s'applique quand ce personnage est PRÉSENT dans l'armée, comme général
-- ou comme héros, quelle que soit sa monture ou sa variante (on rattache character_name à sa carte du builder).
-- Si plusieurs s'appliquent, on retient le plus élevé (avec le plafond par défaut).
-- Les character_name qui ne correspondent à aucune unité du builder sont listés dans
-- tests/intermediate/assert_cap_overrides_resolved.sql (avertissement).

with caps as (
    select unit_set_key, subculture_key, character_name, cap
    from {{ ref('stg_dump__unit_set_to_mp_unit_caps') }}
    where character_name is not null and cap > 0
),

cards as (
    select race_key, unit_key, card_id from {{ ref('int_unit_cards') }}
),

characters as (
    -- character_name est un nom de personnage de bataille (ex. wh3_dlc29_cha_nagash) : il renvoie à son unité
    select character_name, min(unit_type) as unit_key
    from {{ ref('stg_dump__battle_set_piece_armies_characters') }}
    where unit_type is not null group by character_name
)

select
    c.subculture_key        as race_key,
    c.unit_set_key,
    c.character_name,
    k.card_id               as general_card_id,
    c.cap,
    '{{ var("patch") }}'    as patch
from caps c
left join characters ch on ch.character_name = c.character_name
left join cards k on k.race_key = c.subculture_key and k.unit_key = coalesce(ch.unit_key, c.character_name)
