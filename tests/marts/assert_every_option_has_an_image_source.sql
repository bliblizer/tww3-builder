-- Toute option jouable doit avoir une image possible : une carte du jeu, ou un portrait quand la carte est générique.
select race_key, unit_key, unit_name, unit_card, portrait_image
from {{ ref('pvp_roster_options') }}
where (image_source = 'card' and unit_card is null)
   or (image_source = 'portrait' and portrait_image is null)
