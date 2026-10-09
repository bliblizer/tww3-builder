-- Règles générales d'une armée PvP 1v1, lues dans les tables du jeu.
select
    (select budget from {{ ref('stg_dump__mp_budgets') }} where budget_key = 'land_large')                       as budget,
    (select starting_unit_cap from {{ ref('stg_dump__battle_unit_caps_for_team_sizes') }} where team_size = 1)    as max_units,
    1                                                                                                            as nb_generals,
    '{{ var("patch") }}'                                                                                         as patch
