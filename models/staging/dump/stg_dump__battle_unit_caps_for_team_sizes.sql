-- Nombre d'unités max par taille d'équipe (1v1 = 20)
-- Source : db/battle_unit_caps_for_team_sizes_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    cast("team_size" as bigint)                             as team_size,
    cast("max_unit_cap" as bigint)                          as max_unit_cap,
    cast("reinforcement_pool_cap" as bigint)                as reinforcement_pool_cap,
    cast("starting_unit_cap" as bigint)                     as starting_unit_cap,
    cast("addition_to_max_for_first_player" as bigint)      as addition_to_max_for_first_player,
    cast("domination_budget_multiplier" as decimal(18,4))   as domination_budget_multiplier,
    cast("survival_budget_multiplier" as decimal(18,4))     as survival_budget_multiplier,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/battle_unit_caps_for_team_sizes_tables/data__.tsv') }}
