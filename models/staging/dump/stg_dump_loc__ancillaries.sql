-- Textes du jeu : Noms des objets
-- Source : text/db/ancillaries__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/ancillaries__.loc.tsv') }}
