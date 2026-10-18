"""Construction complète du site, dans le bon ordre, en une commande.

  1. dbt build      : données (modèles + tests) — lancé avec « python -m dbt.cli.main » (dbt.exe peut être bloqué sous Windows)
  2. build_app.py   : builder (docs/index.html) et images
  3. build_meta.py  : Faction Guide, Meta Overview, My Armies, Magic (lit docs/index.html : doit passer après build_app)
  4. test_app.py    : verdicts, prix, aller-retour des fichiers du jeu, armées relevées en jeu (si Playwright est installé)

Usage :  python scripts/build_all.py              tout
         python scripts/build_all.py --no-dbt     sans dbt (données déjà construites)
         python scripts/build_all.py --no-tests   sans les tests du builder
S'arrête à la première étape en erreur.
"""
import os, subprocess, sys, importlib.util
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = set(sys.argv[1:])
steps = []
if '--no-dbt' not in args:
    steps.append(('dbt build', [sys.executable, '-m', 'dbt.cli.main', 'build', '--profiles-dir', '.']))
steps += [('build_app', [sys.executable, os.path.join('scripts', 'build_app.py')]),
          ('build_meta', [sys.executable, os.path.join('scripts', 'build_meta.py')])]
if '--no-tests' not in args:
    if importlib.util.find_spec('playwright'):
        steps.append(('test_app', [sys.executable, os.path.join('scripts', 'test_app.py')]))
    else:
        print('(tests du builder ignorés : Playwright n\'est pas installé — pip install playwright puis python -m playwright install chromium)')
for name, cmd in steps:
    print(f'\n=== {name} ===', flush=True)
    if subprocess.run(cmd, cwd=ROOT).returncode != 0:
        sys.exit(f'\nÉchec à l\'étape « {name} » : les étapes suivantes n\'ont pas été lancées.')
print('\nTout est construit. Pense à relire exports/meta_checks.csv et exports/missing_unit_cards.csv avant de pousser.')
