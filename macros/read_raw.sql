{#- Lit un fichier brut du dump (TSV) tel quel :
    - toutes les colonnes en texte (les types sont posés dans chaque modèle de staging)
    - pas de guillemets ni d'échappement : le dump n'en utilise pas, une apostrophe ou un " reste du texte
    - la 2e ligne technique (#nom_table;version;chemin) est retirée -#}
{% macro read_raw(path) %}
(
    select *
    from read_csv('{{ var("raw_root") }}/{{ var("patch") }}/{{ path }}',
                  delim = '\t', header = true, all_varchar = true, quote = '', escape = '',
                  null_padding = true, max_line_size = 10000000, sample_size = -1)
    where not starts_with(coalesce(#1, ''), '#')
)
{% endmacro %}
