-- Unités recrutables par faction (visibilité builder)
-- Source : db/units_custom_battle_permissions_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "faction"                                               as faction_key,
    cast("general_unit" as boolean)                         as general_unit,
    "unit"                                                  as unit_key,
    cast("siege_unit_attacker" as boolean)                  as siege_unit_attacker,
    cast("siege_unit_defender" as boolean)                  as siege_unit_defender,
    "general_portrait"                                      as general_portrait,
    "general_uniform"                                       as general_uniform,
    "set_piece_character"                                   as set_piece_character,
    cast("campaign_exclusive" as boolean)                   as campaign_exclusive,
    "armory_item_set"                                       as armory_item_set,
    cast("supports_upgrades" as boolean)                    as supports_upgrades,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/units_custom_battle_permissions_tables/data__.tsv') }}
