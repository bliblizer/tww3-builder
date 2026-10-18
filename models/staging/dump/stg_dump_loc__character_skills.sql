-- Textes du jeu : Noms des compétences (renvois depuis certains noms de capacités)
-- Source : text/db/character_skills__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/character_skills__.loc.tsv') }}
