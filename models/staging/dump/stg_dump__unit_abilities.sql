-- Définition des capacités et sorts
-- Source : db/unit_abilities_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as ability_key,
    cast("requires_effect_enabling" as boolean)             as requires_effect_enabling,
    "icon_name"                                             as icon_name,
    "overpower_option"                                      as overpower_option,
    "type"                                                  as type,
    "video"                                                 as video,
    "uniqueness"                                            as uniqueness,
    cast("is_unit_upgrade" as boolean)                      as is_unit_upgrade,
    cast("is_hidden_in_ui" as boolean)                      as is_hidden_in_ui,
    "source_type"                                           as source_type,
    "superseded_abilities_set"                              as superseded_abilities_set,
    cast("is_hidden_in_ui_for_enemy" as boolean)            as is_hidden_in_ui_for_enemy,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/unit_abilities_tables/data__.tsv') }}
