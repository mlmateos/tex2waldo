# tex2waldo

Pipeline **LaTeX → Markdown** para producir corpus auditables listos para OpenWALDO.

Nació para convertir los libros de matemáticas de Manuel López Mateos
(memor + tikz + tcolorbox + macros propias) en Markdown limpio para
entrenamiento de IA, conservando la procedencia (DOI de Zenodo, CC-BY-4.0).

## Uso

    ./tex2waldo.sh <dir-libro> <main.tex> <Salida.md>

Ejemplo:

    ./tex2waldo.sh ~/libros/ctos_logic_y_fun MLM-CLF-ebook.tex Conjuntos_Lógica_y_Funciones.md

## Qué hace

1. Copia `.tex`/`.bib` a `<dir>.pandoc` (zona de cuarentena; nunca toca tus fuentes).
2. Sanea: comentarios fuera, TikZ fuera, envoltorios visuales desenvueltos,
   macros del autor expandidas con diccionarios.
3. Aplana `\include{...}` e inyecta un preámbulo mínimo que Pandoc tolera.
4. Convierte con Pandoc (`--citeproc`).

## Roadmap

- [ ] Modo `lint --verbose` (reporta `archivo:línea` sin modificar nada).
- [ ] User-command para TeXstudio ("modo corpus").
- [ ] Diccionarios de macros por libro (`macros.yaml`).

## Procedencia del primer corpus

*Conjuntos, Lógica y Funciones*, 3.ª ed. — https://doi.org/10.5281/zenodo.20433093 (CC-BY-4.0)
