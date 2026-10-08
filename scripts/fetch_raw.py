"""Télécharge les fichiers sources du dump WH3 (github.com/Shazbot/WH3-Dump) pour un patch donné.

Usage :  python scripts/fetch_raw.py <nom_du_patch> <commit_ou_branche>
Exemple : python scripts/fetch_raw.py patch_9.0 8a4f7e64714cf971b44988a4b59f218af6d04ff2

Compléter un patch déjà téléchargé (après ajout d'une ligne dans config/sources.csv) :
          python scripts/fetch_raw.py patch_9.0 --add
  -> télécharge uniquement les fichiers absents, au MÊME commit que le reste du patch (lu dans _source.txt),
     sans jamais toucher aux fichiers déjà présents.

- La liste des fichiers est dans config/sources.csv (ajouter une ligne = ajouter un fichier).
- Les fichiers sont copiés TELS QUELS dans raw/<patch>/ (même arborescence que le dépôt) : on ne les modifie jamais.
- Un manifest (raw/<patch>/_manifest.csv) trace l'origine exacte de chaque fichier (commit, URL, empreinte SHA-256, nb de lignes).
- Le script s'arrête en erreur si un fichier manque ou n'a pas le format attendu.
"""
import csv, hashlib, os, sys, urllib.parse, urllib.request, json
from datetime import datetime, timezone

REPO = 'Shazbot/WH3-Dump'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def main(patch, ref):
    out_dir = os.path.join(ROOT, 'raw', patch)
    add_mode = ref == '--add'
    if add_mode:
        if not os.path.exists(os.path.join(out_dir, '_manifest.csv')):
            sys.exit(f"{out_dir} n'existe pas : télécharge d'abord le patch complet.")
        src = dict(l.split(': ', 1) for l in open(os.path.join(out_dir, '_source.txt'), encoding='utf-8').read().splitlines() if ': ' in l)
        commit = src['commit']
        manifest = list(csv.DictReader(open(os.path.join(out_dir, '_manifest.csv'), encoding='utf-8')))
        done = {m['path'] for m in manifest}
        sources = [s for s in csv.DictReader(open(os.path.join(ROOT, 'config', 'sources.csv'), encoding='utf-8')) if s['path'] not in done]
        if not sources:
            print('Rien à ajouter : tous les fichiers de config/sources.csv sont déjà présents.'); return
        manifest += download(sources, commit, out_dir)
        write_manifest(out_dir, manifest)
        with open(os.path.join(out_dir, '_source.txt'), 'a', encoding='utf-8') as f:
            f.write(f'ajout le: {datetime.now(timezone.utc).isoformat(timespec="seconds")} ({len(sources)} fichiers, même commit)\n')
        print(f'\n{len(sources)} fichier(s) ajouté(s) à {out_dir}  (commit {commit[:7]})')
        return
    # résout le commit exact (une branche comme "main" bouge ; un commit non)
    try:
        with urllib.request.urlopen(f'https://api.github.com/repos/{REPO}/commits/{ref}', timeout=30) as r:
            commit = json.load(r)['sha']
    except Exception:
        if len(ref) != 40: sys.exit(f"Impossible de résoudre '{ref}' en commit : donne le hash complet (40 caractères).")
        commit = ref
    if os.path.exists(os.path.join(out_dir, '_manifest.csv')):
        sys.exit(f'{out_dir} existe déjà : un dossier brut ne doit pas être écrasé. '
                 f'Choisis un autre nom de patch, ou utilise --add pour compléter.')
    sources = list(csv.DictReader(open(os.path.join(ROOT, 'config', 'sources.csv'), encoding='utf-8')))
    manifest = download(sources, commit, out_dir)
    write_manifest(out_dir, manifest)
    with open(os.path.join(out_dir, '_source.txt'), 'w', encoding='utf-8') as f:
        f.write(f'repo: https://github.com/{REPO}\ncommit: {commit}\nref demandé: {ref}\n'
                f'téléchargé le: {datetime.now(timezone.utc).isoformat(timespec="seconds")}\nfichiers: {len(manifest)}\n')
    print(f'\n{len(manifest)} fichiers -> {out_dir}  (commit {commit[:7]})')

def download(sources, commit, out_dir):
    manifest = []
    for s in sources:
        url = f'https://raw.githubusercontent.com/{REPO}/{commit}/' + urllib.parse.quote(s['path'])
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
        text = data.decode('utf-8')                      # échoue si l'encodage n'est pas UTF-8
        n_rows = ''
        if s['path'].endswith('.tsv'):                   # contrôle de format : en-tête + ligne technique #… + lignes de même largeur
            lines = text.split('\n')
            if lines[-1] == '': lines = lines[:-1]
            width = len(lines[0].split('\t'))
            assert lines[1].startswith('#'), f"{s['path']} : 2e ligne technique absente"
            bad = [i for i, l in enumerate(lines[2:], 3) if len(l.split('\t')) != width]
            assert not bad, f"{s['path']} : lignes de largeur incorrecte {bad[:5]}"
            n_rows = len(lines) - 2
        dest = os.path.join(out_dir, *s['path'].split('/'))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, 'wb') as f:
            f.write(data)                                # octets d'origine, sans conversion
        manifest.append({'path': s['path'], 'domain': s['domain'], 'status': s['status'], 'rows': n_rows,
                         'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'url': url})
        print(f"OK  {s['path']}  ({n_rows} lignes)")
    return manifest

def write_manifest(out_dir, manifest):
    with open(os.path.join(out_dir, '_manifest.csv'), 'w', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['path', 'domain', 'status', 'rows', 'bytes', 'sha256', 'url'], lineterminator='\r\n')
        w.writeheader(); w.writerows(manifest)

if __name__ == '__main__':
    if len(sys.argv) != 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
