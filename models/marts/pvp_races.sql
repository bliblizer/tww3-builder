-- Les races jouables en PvP, avec la taille de leur roster et leur identité visuelle.
-- Grain : 1 ligne par race.
--   main_faction_key : faction de la race qui a le plus d'unités jouables (sert aux couleurs et à l'illustration)
--   accent_hex       : couleur principale de cette faction (factions.primary_colour_hex) ; si elle est trop sombre
--                      pour un fond sombre, sa couleur secondaire ; sinon vide (l'application garde son rouge par défaut)
--   race_image       : illustration de la race utilisée par l'écran de bataille personnalisée du jeu
--                      (ui/frontend ui/race_strip_images/<race_image>.png, à extraire avec RPFM)

with cards as (
    select race_key, any_value(race_name) as race_name, count(*) as nb_cards, sum(nb_options) as nb_options,
           count(*) filter (where can_be_general) as nb_cards_general
    from {{ ref('pvp_roster_cards') }}
    group by race_key
),

main_faction as (
    select race_key, arg_max(faction_key, n) as faction_key
    from (select race_key, faction_key, count(*) as n
          from {{ ref('int_unit_faction_status') }} where is_selectable_pvp group by all)
    group by race_key
),

colours as (
    select faction_key, primary_colour_hex, secondary_colour_hex,
           -- luminance perçue (0 à 255) d'une couleur hexadécimale
           (0.299 * ('0x' || substr(primary_colour_hex, 1, 2))::int + 0.587 * ('0x' || substr(primary_colour_hex, 3, 2))::int
            + 0.114 * ('0x' || substr(primary_colour_hex, 5, 2))::int)   as primary_luma,
           (0.299 * ('0x' || substr(secondary_colour_hex, 1, 2))::int + 0.587 * ('0x' || substr(secondary_colour_hex, 3, 2))::int
            + 0.114 * ('0x' || substr(secondary_colour_hex, 5, 2))::int) as secondary_luma
    from {{ ref('stg_dump__factions') }}
)

select
    c.race_key,
    c.race_name,
    c.nb_cards,
    c.nb_options,
    c.nb_cards_general,
    m.faction_key                                                          as main_faction_key,
    case when col.primary_luma >= 60 then col.primary_colour_hex
         when col.secondary_luma >= 60 then col.secondary_colour_hex end  as accent_hex,
    m.faction_key || '_large'                                              as race_image,
    '{{ var("patch") }}'                                                   as patch
from cards c
join main_faction m using (race_key)
left join colours col on col.faction_key = m.faction_key
