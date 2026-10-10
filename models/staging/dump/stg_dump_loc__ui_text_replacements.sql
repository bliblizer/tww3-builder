-- Textes du jeu : Textes de remplacement référencés par les renvois tr (ex. Vanguard Deployment)
-- Source : text/db/ui_text_replacements__.loc.tsv
select
    "key"                             as loc_key,
    "text"                            as text,
    cast("tooltip" as boolean)        as is_tooltip,
    '{{ var("patch") }}'            as patch
from {{ read_raw('text/db/ui_text_replacements__.loc.tsv') }}
