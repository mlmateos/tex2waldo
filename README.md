# tex2waldo

**LaTeX → Markdown** pipeline for producing auditable, provenance-rich AI training corpora compatible with [OpenWALDO](https://github.com/openwaldo).

Born to convert mathematics textbooks (memoir + tikz + tcolorbox + custom macros) into clean Markdown suitable for AI training, while preserving full provenance (Zenodo DOIs, CC-BY-4.0 licensing).

## Prerequisites

Before running the pipeline, ensure you have the following installed on your system:
- **Bash** (v4.0+)
- **Python 3** (requires standard library modules `re` and `pathlib`)
- **Pandoc** (v2.11 or higher, which includes built-in `--citeproc`)

*On Debian/Ubuntu systems, you can install Pandoc via:* `sudo apt install pandoc`

## Quick Start

1. Make the script executable:
   ```bash
   chmod +x tex2waldo.sh
   ```

2. Run the pipeline against your book directory:
   ```bash
   ./tex2waldo.sh <book-dir> <main.tex> <Output.md>
   ```

   **Example:**
   ```bash
   ./tex2waldo.sh ~/libros/ctos_logic_y_fun MLM-CLF-ebook.tex ~/projects/waldo-math-md/Conjuntos_Lógica_y_Funciones.md
   ```

### Advanced Usage

- **Strip Frontmatter**: To surgically remove graphical cover/title pages (e.g., files matching `00.tapa.tex` or `0a.portada-ebook.tex`) while preserving legal pages and introductions, use the `--strip-frontmatter` flag:
  ```bash
  ./tex2waldo.sh --strip-frontmatter ~/libros/ctos_logic_y_fun MLM-CLF-ebook.tex Output.md
  ```

- **Reproducible Builds**: To freeze the `\today` macro for bit-identical builds across different days, set the `TEX2WALDO_TODAY` environment variable (format: `YYYY-MM-DD`):
  ```bash
  TEX2WALDO_TODAY=2026-08-20 ./tex2waldo.sh ~/libros/ctos_logic_y_fun MLM-CLF-ebook.tex Output.md
  ```

## What it does

1. **Quarantine**: Copies `.tex`/`.bib` files to `<book-dir>.pandoc` (the pipeline **never** modifies your original sources).
2. **Sanitizes**: Strips comments, removes TikZ drawings, unwraps visual containers (`minipage`, `hbox`, `vbox`), and expands author macros (0 and 1 argument) via internal dictionaries. It also cleans up internal TeX machinery (e.g., `\makeatletter` blocks, orphaned `\let`, and complex `DESCRIPTION` environments).
3. **Flattens**: Recursively resolves `\include{...}` directives (up to 10 levels) and injects a minimal preamble that Pandoc tolerates.
4. **Converts**: Invokes Pandoc with `--citeproc` for bibliography resolution and `--wrap=none` for clean Markdown output.

## Design philosophy

- **Separation of concerns**: The pipeline operates on copies, guaranteeing your source LaTeX remains pristine.
- **Provenance-first**: Output is ready for ingestion into OpenWALDO with full BOM (Bill of Materials) including source DOI, license, and SHA-256 hashes.
- **Reproducible**: Environment variables allow freezing dynamic content like dates.

## Roadmap

- [x] `--strip-frontmatter` flag for surgical removal of graphical covers.
- [x] Reproducible builds via `TEX2WALDO_TODAY`.
- [x] Deep sanitization of internal TeX machinery (`\makeatletter`, orphaned `\let`, etc.).
- [ ] `lint --verbose` mode: reports `file:line` semantic issues without modifying sources.
- [ ] TeXstudio/Iguana integration ("corpus mode" user-command).
- [ ] Per-book macro dictionaries (`macros.yaml`) for complex macros (2+ arguments).

## First corpus provenance

*Conjuntos, Lógica y Funciones* (Sets, Logic, and Functions), 3rd ed. — https://doi.org/10.5281/zenodo.20433093 (CC-BY-4.0)

## License

This pipeline is free software. Use it to contribute auditable corpora to the AI commons.

