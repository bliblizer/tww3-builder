-- Textes du jeu : Noms des personnages (renvois depuis land_units)
-- Source : text/db/agent_subtypes__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/agent_subtypes__.loc.tsv') }}
