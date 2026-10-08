{#- Utilise le nom de schéma tel quel (staging, intermediate, marts) au lieu de le préfixer par la cible -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name if custom_schema_name else target.schema }}
{%- endmacro %}
