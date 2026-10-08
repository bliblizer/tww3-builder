-- Image de carte de chaque land unit : unit_card = nom du fichier dans ui/units/icons/ (sans extension).
-- Attention : la colonne « unit » du jeu contient une clé de LAND unit (main_units.land_unit_key), pas de main unit.
-- faction_key renseignée = image propre à une faction (21 lignes, aucune ne concerne le PvP au patch 9.0).
-- Source : db/unit_variants_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "faction"                                               as faction_key,
    "unit"                                                  as land_unit_key,
    "name"                                                  as variant_name,
    "variant"                                               as variant_key,
    "unit_card"                                             as unit_card,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_variants_tables/data__.tsv') }}
