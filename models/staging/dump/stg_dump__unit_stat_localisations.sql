-- Statistiques -> clé de texte
-- Source : db/unit_stat_localisations_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "stat_key"                                              as stat_key,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_stat_localisations_tables/data__.tsv') }}
