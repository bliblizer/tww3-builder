-- Chaque armée de test doit recevoir exactement le verdict attendu (validité + liste des erreurs).
select v.army_id, x.description, x.expected_valid, v.is_valid, x.expected_errors, v.errors
from {{ ref('army_validation') }} v
full outer join {{ ref('test_army_expectations') }} x using (army_id)
where v.is_valid is distinct from x.expected_valid
   or coalesce(v.errors, '') is distinct from coalesce(x.expected_errors, '')
