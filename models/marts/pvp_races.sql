-- Les races jouables en PvP, avec la taille de leur roster.
-- Grain : 1 ligne par race.

select
    race_key,
    any_value(race_name)                          as race_name,
    count(*)                                      as nb_cards,
    sum(nb_options)                               as nb_options,
    count(*) filter (where can_be_general)        as nb_cards_general,
    '{{ var("patch") }}'                          as patch
from {{ ref('pvp_roster_cards') }}
group by race_key
