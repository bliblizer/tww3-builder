-- Budgets par type de bataille (land_large = 12400)
-- Source : db/mp_budgets_tables/data__.tsv  (types déduits du patch 9.0 : un cast qui échoue sur un nouveau patch signale un changement de format)
select
    "key"                                                   as budget_key,
    cast("budget" as bigint)                                as budget,
    "budget_size_key"                                       as budget_size_key,
    cast("land" as boolean)                                 as land,
    cast("siege_defender" as boolean)                       as siege_defender,
    '{{ var("patch") }}' as patch
from {{ read_raw('db/mp_budgets_tables/data__.tsv') }}
