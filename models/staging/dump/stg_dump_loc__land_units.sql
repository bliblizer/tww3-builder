-- Textes du jeu : Noms des unités
-- Source : text/db/land_units__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/land_units__.loc.tsv') }}
