# tex2waldo

**LaTeX → Markdown** pipeline for producing auditable, provenance-rich AI training corpora compatible with [OpenWALDO](https://github.com/openwaldo).

Born to convert mathematics textbooks (memoir + tikz + tcolorbox + custom macros) into clean Markdown suitable for AI training, while preserving full provenance (Zenodo DOIs, CC-BY-4.0 licensing).

## Usage

    ./tex2waldo.sh <book-dir> <main.tex> <Output.md>

Example:

    ./tex2waldo.sh ~/books/sets-logic-functions MLM-ebook.tex Sets_Logic_Functions.md

## What it does

1. Copies `.tex`/`.bib` files to `<book-dir>.pandoc` (quarantine zone; **never touches your sources**).
2. **Sanitizes**: strips comments, removes TikZ drawings, unwraps visual containers, expands author macros via dictionaries.
3. **Flattens** `\include{...}` directives and injects a minimal preamble that Pandoc tolerates.
4. **Converts** via Pandoc (`--citeproc` for bibliography resolution).

## Design philosophy

- **Separation of concerns**: the pipeline never modifies original `.tex` sources; it works on copies.
- **Provenance-first**: output is ready for ingestion into OpenWALDO with full BOM (Bill of Materials) including source DOI, license, and SHA-256 hashes.
- **Reproducible**: set `TEX2WALDO_TODAY=YYYY-MM-DD` to freeze `\today` expansion for bit-identical builds.

## Roadmap

- [ ] `lint --verbose` mode: reports `file:line` issues without modifying sources.
- [ ] TeXstudio integration ("corpus mode" user-command).
- [ ] Per-book macro dictionaries (`macros.yaml`).

## First corpus provenance

*Conjuntos, Lógica y Funciones* (Sets, Logic, and Functions), 3rd ed. — https://doi.org/10.5281/zenodo.20433093 (CC-BY-4.0)

## License

This pipeline is free software. Use it to contribute auditable corpora to the AI commons.
