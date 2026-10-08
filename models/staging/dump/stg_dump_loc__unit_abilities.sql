-- Textes du jeu : Noms des capacités et sorts
-- Source : text/db/unit_abilities__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/unit_abilities__.loc.tsv') }}
