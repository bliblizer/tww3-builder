# tww3-builder

Builder de composition d'armée PvP pour Total War: Warhammer 3.

## Organisation

```
config/sources.csv              liste des fichiers du dump à récupérer (1 ligne = 1 fichier)
scripts/fetch_raw.py            téléchargement d'un patch dans raw/<patch>/
scripts/generate_staging.py     crée le modèle de staging d'un nouveau fichier source
raw/<patch>/                    fichiers bruts du dump, JAMAIS modifiés
  _source.txt                   dépôt + commit exact + date de téléchargement
  _manifest.csv                 chaque fichier : domaine, statut, lignes, taille, SHA-256, URL
models/staging/dump/            1 modèle dbt par fichier brut + stg_loc_texts (tous les textes, renvois résolus)
macros/read_raw.sql             lecture d'un fichier brut (TSV du dump)
models/intermediate/            règles du jeu (race des factions, statut PvP des unités…)
seeds/reference/                résultats figés de la V0 (scripts Python), pour les tests de non-régression
tests/                          tests transverses et tests métier
dbt_project.yml, profiles.yml   configuration dbt / DuckDB
tww3.duckdb                     base produite par dbt (non versionnée, se reconstruit)
docs/                           site publié par GitHub Pages (application builder)
models/marts/                   tables finales du builder PvP (roster par race)
```

## Lancer le projet (Windows)

Prérequis : Python 3.10 ou plus récent, installé depuis python.org en cochant « Add Python to PATH ».

**Première installation.** Dans le terminal de VS Code ouvert dans le dossier `tww3-builder`, tape une ligne à la fois :

```
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
python -m venv .venv
.venv\Scripts\activate
pip install dbt-duckdb
dbt build --profiles-dir .
```

La première ligne n'est à faire qu'une fois : elle autorise PowerShell à exécuter les scripts, dont celui qui active l'environnement.

**Ensuite, à chaque ouverture du terminal :**

```
.venv\Scripts\activate
dbt build --profiles-dir .
```

Vérifie que `(.venv)` apparaît en début de ligne avant de lancer dbt.
Le résultat attendu est `Done. PASS=190 WARN=1 ERROR=0`. L'avertissement est volontaire, voir « Caps et validation ».

Pour regarder une table : `dbt show --select int_unit_faction_status --profiles-dir .`
Pour une exploration plus confortable, ouvre `tww3.duckdb` avec DBeaver. Les schémas sont `staging`, `intermediate`, `marts` et `reference`.
Pour récupérer les tables en CSV : `python scripts/export_tables.py`. Les fichiers sont écrits dans `exports/`, pour les schémas intermediate et marts.

## Couche staging : conventions

- **Un modèle par fichier brut.** Les modèles s'appellent `stg_dump__<table>` pour les données et `stg_dump_loc__<table>` pour les textes.
- **Contenu identique au brut.** Seuls trois changements sont appliqués :
  - les **types** sont posés : booléen, entier, décimal à 4 chiffres, texte ;
  - les **clés** sont renommées de façon homogène (`unit_key`, `faction_key`, `subculture_key`, `tab_key`, `ui_group_key`…) ;
  - une colonne `patch` est ajoutée à chaque table.
- **Vérification.** Chaque valeur a été comparée au fichier brut, sur les 43 modèles, sans aucun écart. Le test `assert_staging_row_counts_match_manifest` refait en continu la comparaison du nombre de lignes avec le manifest.
- **Types figés sur le patch 9.0.** Si un patch introduit une valeur d'un autre type, le `cast` échoue. C'est voulu : cela signale un changement de format au lieu de le laisser passer.
- **`stg_loc_texts`.** Ce modèle rassemble les 30 432 textes chargés et résout les renvois d'un texte vers un autre (`resolved_text`). Tous les noms utiles au builder sont résolus : unités, montures, races, onglets, sous-groupes. Les 330 renvois restants (`has_unresolved_reference`) visent des fichiers non chargés. Ils concernent des descriptions, des tooltips et des capacités de campagne, à traiter si besoin à l'étape des sorts.
- **Clés primaires testées.** Elles sont testées (unique + non nulle) sur 23 tables. `unit_set_to_unit_junctions` et les tables de liaison n'ont pas de clé unique, par nature.

## Couche intermediate : les règles du jeu

| Modèle | Grain | Contenu |
|---|---|---|
| `int_faction_race` | faction | Race de chaque faction (`race_key` = sous-culture), noms affichés, `has_builder_units` |
| `int_unit_faction_status` | faction × unité du builder | Visible, sélectionnable en PvP, motif du blocage (`campaign_exclusive`, `zero_cap` ou les deux), groupes de caps à 0 en cause, coût, caste, sous-groupe, onglet |
| `int_race_units` | race × unité | Statuts fusionnés au niveau de la race (sélectionnable si au moins une faction de la race l'autorise), nom de l'unité, factions |
| `int_unit_option_labels` | unité (montures et variantes) | Version à pied, nom de la monture, domaine / marque / esprit de la forêt / autre variante |
| `int_unit_cards` | race × unité | Carte de rattachement (`card_id`), unité racine, nom de carte, libellés d'options. Calculé sur tout le périmètre, PvP ou non |

**Regroupement en cartes** (`int_unit_cards`). Deux unités d'une même race sont sur la même carte si l'une est la monture ou la variante de l'autre, de proche en proche (requête récursive).

L'unité racine donne son nom, son onglet et son sous-groupe à la carte. On la choisit selon ces critères, dans l'ordre :
1. une unité à pied plutôt que montée ;
2. une base de variante affichée dans le jeu ;
3. une base de variante plutôt qu'une variante ;
4. la moins chère ;
5. en dernier recours, l'ordre alphabétique de la clé.

Le nom de carte est celui de la racine, sans la parenthèse de sa variante : « Spellweaver (Beasts) » devient « Spellweaver ».

**Onglet des lords (marts).** Une carte dont l'unité racine est un lord (caste `lord`) pouvant être général est placée dans l'onglet **Lords**, même si son sous-groupe d'interface est rattaché aux Heroes. C'est le cas de personnages qui sont des héros en campagne mais des lords en PvP : Drycha, Vlad et Isabella von Carstein *(validé en jeu)*, et les Great Shaman-Sorcerers de Norsca. L'onglet d'origine reste visible dans `pvp_roster_cards.ui_group_tab_key`.

Règle PvP : une unité présente dans les permissions de la faction est **visible**. Elle est **bloquée** si elle est `campaign_exclusive`, ou si elle appartient à un groupe de caps à 0 qui s'applique à la race de la faction (cap global ou cap de cette sous-culture).

Tests associés (`tests/intermediate/`) :
- `assert_unit_faction_status_matches_v0` : non-régression. Les 2 941 couples sont identiques à la V0 (`seeds/reference`). Un test de mutation l'a vérifié : en cassant volontairement la règle des sous-cultures, 230 écarts sont détectés.
- `assert_known_pvp_statuses` : cas validés en jeu (Coeddil interdit, Durthu, Sigvald) et cas témoins (Crypt Ghouls chez les Tomb Kings, Spawn of Khorne selon la faction).
- `assert_unit_cards_match_v0` : non-régression du regroupement (1 797 cartes) et des libellés (2 941 options) contre la V0. Il y a 18 écarts assumés, listés dans `ref_v0_accepted_differences.csv`. Ce sont des noms de monture que la V0 déduisait de l'icône faute de texte (« Sky Cutter »), et qui sont maintenant les noms officiels du jeu (« Skycutter Chariot », « Kuhl'tyran »…).
- `assert_zero_cap_rules_hold` : vérifie les hypothèses de la règle. Il n'existe aucun cap à 0 propre à un personnage, aucune exclusion, et les membres sont toujours désignés par unité ou par caste. Si un patch les casse, la règle est à revoir.

## Couche marts : le roster PvP

| Modèle | Grain | Contenu |
|---|---|---|
| `pvp_races` | race | 25 races, avec leur nombre de cartes, d'options et de cartes pouvant être général |
| `pvp_roster_cards` | carte jouable | Nom, onglet (ordre et nom du jeu), sous-groupe, général possible, nombre d'options, vrai choix de variante / de monture, coût min/max |
| `pvp_roster_options` | race × unité jouable | Carte, clé d'unité (celle des `.army_setup`), domaine, marque, esprit, autre variante, monture (« On foot » pour la version à pied), général possible, coût |

**Principe : on filtre d'abord, on calcule ensuite.** Seules les options sélectionnables en PvP sont gardées, et une carte sans option jouable disparaît. Toutes les colonnes calculées le sont après ce filtre :
- `has_variant_choice` vaut true seulement s'il existe au moins deux combinaisons de variantes différentes parmi les options PvP ;
- les coûts minimum et maximum ne tiennent compte que des options jouables.

Tests (`tests/marts/`) :
- `assert_pvp_known_cards` vérifie les cas suivants :
  - Spellweaver : 20 options (5 domaines × 4 montures) ;
  - Coeddil absent du roster ;
  - Ancient Treeman : 1 option, sans choix ;
  - Chaos Lord of Khorne : sans faux choix de variante ;
  - Chaos Sorcerer Lord : domaine, marque et monture sur une seule carte ;
  - les unités de tes deux fichiers `.army_setup` sont présentes, sauf Coeddil.
- `assert_pvp_texts_are_clean` : aucun nom vide ni texte non résolu.

Un test de mutation a vérifié l'efficacité de ces tests : en supprimant volontairement les liens de montures, 3 454 écarts et 3 cas connus en échec sont détectés.

## Application builder (V0)

```
app/template.html        mise en page et code de l'application (HTML + CSS + JavaScript, sans bibliothèque)
scripts/build_app.py     lit les tables marts de tww3.duckdb et injecte les données dans le gabarit
docs/index.html          application produite, autonome (données incluses) : double-clic pour l'ouvrir.
                         C'est aussi le dossier publié en ligne par GitHub Pages.
```

Pour la reconstruire après un `dbt build` : `python scripts/build_app.py`.
Un fichier source s'ajoute à un patch déjà téléchargé avec `python scripts/fetch_raw.py patch_9.0 --add`. Le fichier est téléchargé au même commit, sans toucher aux autres.

Fonctions de la V0 :
- sélection de la race (flèches ◀ ▶, liste déroulante ou Alt + ← / →) ;
- roster en sections par onglet du jeu, cartes triées par coût croissant ;
- clic sur une carte pour l'ajouter à l'armée. Si elle a plusieurs options, on choisit d'abord le domaine, la marque ou la monture ;
- clic sur une unité de l'armée pour la retirer ;
- fonds restants (12 400) et 20 unités maximum, lus dans les tables du jeu ;
- panneau de détail au survol.

Limites de la V0 :
- prix de base, sans objets ni sorts ;
- pas de caps ni de validation de l'armée.

### Images des cartes

Les images ne sont pas dans le dump GitHub. Elles viennent des fichiers du jeu installé.
Le lien unité → image vient de la table `unit_variants` (`int_unit_card_images`, colonnes `unit_card` des marts). Les 2 698 options PvP ont une image référencée, soit 1 142 fichiers distincts.

1. Avec **RPFM**, extrais le dossier `ui/units/icons/` des packs du jeu.
2. Copie son contenu dans `assets/unit_cards/` à la racine du projet. Les sous-dossiers sont acceptés.
3. Lance `python scripts/build_app.py`. Il copie uniquement les images utiles dans `docs/images/` et liste les manquantes dans `exports/missing_unit_cards.csv`.

Points à retenir :
- `assets/` est **exclu de Git** : ce sont les originaux du jeu. Seules les images utiles au site, dans `docs/images/`, sont versionnées et publiées.
- Une carte sans image s'affiche avec sa couleur d'onglet et les initiales du nom.

## Caps et validation de l'armée

**Données** (marts) :
- `pvp_army_rules` : budget (12 400) et nombre maximal d'unités (20), lus dans les tables du jeu ;
- `pvp_cap_groups` : groupes de caps par race, avec leur plafond par défaut (1 424 lignes) ;
- `pvp_cap_group_members` : appartenance des unités jouables aux groupes. Toute unité jouable appartient à au moins un groupe (son plafond individuel) ;
- `pvp_cap_overrides` : plafonds qui dépendent d'un personnage présent dans l'armée (27 lignes, chez les Undead Legions) ;
- `pvp_roster_options.is_lord` : l'option est un lord (caste `lord`).

**Règles :**
1. **Un seul lord par armée**, en première place, et c'est le général (♛) *(validé en jeu)*. Dans le builder, choisir un lord remplace le précédent, comme en jeu.
2. **20 unités au maximum.**
3. **Coût total de 12 400 au maximum** (prix de base pour l'instant).
4. **Chaque groupe de caps** limite le nombre total de ses membres dans l'armée. Une unité appartient souvent à plusieurs groupes (plafond individuel, chars et machines de guerre, héros, unités de tir…), et toutes les limites s'appliquent en même temps.
5. Le plafond par défaut d'un groupe est celui de la sous-culture s'il existe, sinon le plafond global.
6. Les **plafonds liés à un personnage** s'appliquent dès que ce personnage est présent dans l'armée, comme général ou comme héros, quelle que soit sa monture *(validé en jeu)*. Si plusieurs s'appliquent, c'est le plus élevé qui compte.
7. **2 héros au maximum** : c'est le groupe « Heroes » des données *(validé en jeu)*.

**Une spécification, deux implémentations, testées ensemble :**
- `models/validation/army_validation.sql` est la spécification exécutable. Elle s'applique aux armées de test de `seeds/tests/test_armies.csv` : tes deux fichiers `.army_setup` et un cas construit par règle.
- Le test `assert_army_validation_matches_expectations` compare chaque verdict à l'attendu de `test_army_expectations.csv` (10 armées, codes d'erreur : NO_GENERAL, MULTIPLE_LORDS, UNIT_NOT_AVAILABLE, TOO_MANY_UNITS, OVER_BUDGET, CAP_EXCEEDED:<groupe>).
- Le builder (`app/template.html`, fonction `validate`) applique les mêmes règles. `python scripts/test_app.py` (facultatif) vérifie qu'il rend les mêmes verdicts, avec Playwright :

```
pip install playwright
python -m playwright install chromium
```

**Avertissement attendu :** `assert_cap_overrides_resolved` signale 7 plafonds liés à des personnages qu'on ne sait pas rattacher à une carte (Nagash, Arkhan, Liche Priest, Vampire Lord, Mourngul). Ils sont ignorés pour l'instant.

**Dans le builder :**
- Tant qu'il n'y a pas de lord, seuls les lords pouvant être généraux sont disponibles.
- Une carte est grisée quand aucune de ses options ne peut être ajoutée (fonds, armée complète, plafond atteint). Le survol en donne la raison.
- Sous l'armée s'affichent le statut (« ✓ Armée valide » ou la liste des problèmes) et les plafonds en cours : en or quand ils sont atteints, en rouge quand ils sont dépassés.

## Git et GitHub

**Ce qui est versionné :** `raw/`, `config/`, `models/`, `macros/`, `seeds/`, `tests/`, `scripts/`, `app/template.html`, `docs/` (le site) et ce README.
**Ce qui ne l'est pas** (voir `.gitignore`) : `tww3.duckdb`, `target/`, `logs/`, `exports/`, `.venv/`, ainsi que les images originales extraites du jeu (`assets/`).

**Routine après une modification**, avec GitHub Desktop :
1. Relance `dbt build --profiles-dir .`, puis `python scripts/build_app.py` si le builder doit changer.
2. Dans GitHub Desktop, onglet **Changes** : relis les fichiers modifiés.
3. Écris un résumé en bas à gauche, par exemple « Roster : ajout des images », puis clique sur **Commit to main**.
4. Clique sur **Push origin**. Le code est sauvegardé sur GitHub, et le site en ligne se met à jour en une à deux minutes.

## Mettre à jour pour un nouveau patch

```
python scripts/fetch_raw.py patch_9.1 <hash du commit WH3-Dump>
dbt build --profiles-dir . --vars "patch: patch_9.1"
python scripts/build_app.py
```

Après un ajout de ligne dans `config/sources.csv`, lance d'abord `python scripts/generate_staging.py patch_9.1` pour créer le modèle du nouveau fichier.

## Récupérer un nouveau patch

```
python scripts/fetch_raw.py patch_9.1 <hash du commit WH3-Dump>
```

Le script refuse d'écraser un dossier existant. Les anciens patchs restent donc disponibles pour comparer.
Pour ajouter une table : ajoute une ligne dans `config/sources.csv`, puis relance le script sur un nouveau dossier de patch.

## Statut des sources (patch 9.0, commit 8a4f7e6)

- **confirmé** (27) : rôle établi et déjà utilisé (roster, options, caps, budget, nombre d'unités, textes, forces/faiblesses).
- **candidat** (16) : tables repérées pour les sorts, les objets et l'expérience, dont le rôle reste à valider.
- **référence** (1) : l'écran du builder (`custom_battle.twui.xml`), qui sert de preuve pour les règles d'affichage. Ce n'est pas une donnée.

Questions ouvertes à valider en jeu :
- **Coût de l'expérience.** `unit_stats_land_experience_bonuses` donne, pour chaque rang, un coût fixe (`mp_fixed_cost`, 11 par rang) et un multiplicateur (`mp_experience_cost_multiplier`, de 1.03 à 1.27). La formule exacte reste à confirmer sur une unité dont on connaît le prix.
- **Coût des objets.** Aucune colonne de coût explicite n'a été trouvée. Piste : `ancillaries.uniqueness_score`, qui vaut 200 pour Daith's Sword, Sliverslash, Auric Armour et Doombells. À comparer au prix affiché en jeu.
- **Sorts.** Il faut confirmer que les domaines proposés en bataille personnalisée viennent de `special_ability_groups_to_units_junctions`.
