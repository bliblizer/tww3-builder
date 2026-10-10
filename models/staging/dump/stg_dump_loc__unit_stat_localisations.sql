-- Textes du jeu : Noms des statistiques
-- Source : text/db/unit_stat_localisations__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/unit_stat_localisations__.loc.tsv') }}
