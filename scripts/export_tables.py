"""Exporte les tables de la base tww3.duckdb en fichiers CSV, pour les ouvrir dans Excel, Power BI, etc.

Usage (terminal VS Code, avec (.venv) actif, dans le dossier tww3-builder) :
    python scripts/export_tables.py                  -> exporte les schémas intermediate et marts
    python scripts/export_tables.py staging          -> exporte un autre schéma (staging, reference…)

Les fichiers sont écrits dans exports/<schéma>/<table>.csv (UTF-8, séparateur virgule) et sont
écrasés à chaque export : relance-le après chaque `dbt build` pour avoir des fichiers à jour.
"""
import os, sys
import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, 'tww3.duckdb')
schemas = sys.argv[1:] or ['intermediate', 'marts']

if not os.path.exists(DB):
    sys.exit("tww3.duckdb introuvable : lance d'abord `dbt build --profiles-dir .`")
try:
    con = duckdb.connect(DB, read_only=True)
except duckdb.IOException:
    sys.exit("La base est ouverte ailleurs (DBeaver ?) : ferme la connexion puis relance.")

for schema in schemas:
    tables = [t for (t,) in con.execute(
        "select table_name from information_schema.tables where table_schema = ? order by 1", [schema]).fetchall()]
    if not tables:
        print(f"(schéma '{schema}' vide ou inexistant)")
        continue
    out_dir = os.path.join(ROOT, 'exports', schema)
    os.makedirs(out_dir, exist_ok=True)
    for t in tables:
        path = os.path.join(out_dir, f'{t}.csv')
        con.execute(f'copy "{schema}"."{t}" to \'{path}\' (header, delimiter \',\')')
        n = con.execute(f'select count(*) from "{schema}"."{t}"').fetchone()[0]
        print(f'{schema}.{t}  ->  exports/{schema}/{t}.csv  ({n} lignes)')
