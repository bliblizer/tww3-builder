-- Surcharges d'affichage des variantes par faction
-- Source : db/units_custom_battle_types_to_factions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "faction"                                               as faction_key,
    cast("type" as bigint)                                  as type_id,
    cast("override_show_in_unit_list" as boolean)           as override_show_in_unit_list,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/units_custom_battle_types_to_factions_tables/data__.tsv') }}
