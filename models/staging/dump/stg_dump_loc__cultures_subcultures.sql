-- Textes du jeu : Noms des races
-- Source : text/db/cultures_subcultures__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/cultures_subcultures__.loc.tsv') }}
