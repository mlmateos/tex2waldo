#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# tex2waldo.sh - Pipeline LaTeX -> Markdown (corpus auditable)
# Uso: ./tex2waldo.sh <dir-libro> <main.tex> <Nombre_Salida.md>
# ============================================================================

if [ $# -ne 3 ]; then
  echo "Uso: $0 <dir-libro> <main.tex> <Nombre_Salida.md>"
  exit 1
fi

SRC="$1"
MAIN_TEX="$2"
OUTPUT_MD="$3"
BUILD="${SRC}.pandoc"

echo "[1/4] Preparando entorno limpio..."
rm -rf "$BUILD"
mkdir -p "$BUILD"
cp "$SRC"/*.tex "$BUILD"/
cp "$SRC"/*.bib "$BUILD"/ 2>/dev/null || true
cd "$BUILD"

echo "[2/4] Saneamiento + expansión de macros..."
python3 - <<'PY'
import re
from pathlib import Path

ARG = r'(\{(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*\})'
NESTED2 = r'\{(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*\}'
OPT = r'(?:\[[^\]]*\])?'

def strip_comments(t): return re.sub(r'(?<!\\)%.*', '', t)
def drop_env(t, n):    return re.sub(r'\\begin\{%s\}.*?\\end\{%s\}' % (n, n), '', t, flags=re.S)
def unwrap_env(t, n):
    t = re.sub(r'\\begin\{%s\}%s(?:%s)?' % (n, OPT, NESTED2), '', t)
    return re.sub(r'\\end\{%s\}' % n, '', t)
def drop_cmd(t, n):    return re.sub(r'\\%s%s%s' % (n, OPT, NESTED2), '', t)

NO_ARGS = {
 'longlongrightarrow':'\\longrightarrow', 'equivdef':'\\equiv',
 'greekf':'', 'emoji':'', 'authorinfo':'',
 'cttache':'', 'ctache':'', 'ttache':'', 'tache':'',
 'strutt':'', 'Tstrut':'', 'Bstrut':'',
 'nprecede':'\\not\\preccurlyeq', 'nrel':'\\not R',
 'precede':'\\preccurlyeq', 'rel':'R',
 'imagen':'\\operatorname{Im}', 'vacio':'\\emptyset',
 'grados':'^\\circ', 'talque':'\\mid', 'tq':' \\text{ tal que } ',
 'implica':'\\Rightarrow', 'lxor':'\\veebar',
 'por':'\\times', 'cruz':'\\times', 'ds':'\\displaystyle',
 'nin':'', 'ss':' ',
 'euler':'\\textsc{Euler}', 'venn':'\\textsc{Venn}',
 'qed':'\\blacksquare', 'fej':'',
 'dem':'\\textbf{Demostración.} ', 'resp':'\\textbf{Respuesta.} ',
 'solu':'\\textbf{Solución.} ',
 'ac':'a.~C.', 'dc':'d.~C.',
 'yq':' \\text{ y } ', 'y':' \\text{ y } ', 'o':' \\text{ ó } ',
 'de':'\\colon', 'en':'\\to', 'iff':'\\Leftrightarrow',
 'Exists':'\\exists', 'Forall':'\\forall',
 'beq':'=', 'bneg':'\\neg', 'bbitneg':'\\sim', 'bbitand':'\\&',
 'bbitor':'|', 'bbitOrr':'\\operatorname{OR}',
 'bbitxor':'\\operatorname{XOR}', 'bbitnand':'\\operatorname{NAND}',
 'bbitnor':'\\operatorname{NOR}', 'bbitxnor':'\\operatorname{XNOR}',
 'bwedge':'\\wedge', 'bvee':'\\vee', 'bveebar':'\\veebar',
 'brightarrow':'\\rightarrow', 'bleftrightarrow':'\\leftrightarrow',
 'bequiv':'\\equiv',
 'R':'\\mathbb{R}', 'N':'\\mathbb{N}', 'Q':'\\mathbb{Q}', 'Z':'\\mathbb{Z}',
 'collection':'MATEMÁTICAS PARA TODO',
}

ONE_ARG = {
 'inv':'{%s}^{-1}', 'comp':'{%s}^{\\mathsf{c}}', 'bcomp':'{%s}^{\\mathsf{c}}',
 'un':'%s', 'gr':'%s^\\circ', 'im':'\\operatorname{Im}_{%s}',
 'code':'\\texttt{%s}', 'cur':'%s', 'curn':'%s', 'tmem':'%s',
 'ver':'%s', 'vern':'%s', 'n':'%s', 'sfbf':'%s', 'sfsc':'%s',
 'sfbacti':'%s', 'annus':'%s',
 'actitit':'\\textbf{%s} ', 'actititb':'\\textbf{%s}',
 'probletit':'\\textbf{%s}',
}

TRIV = ['pregunta','propiedad','definition','teorema','afir','ejemplo','actividad','ejers','ejer']

for f in sorted(Path('.').glob('*.tex')):
    t = f.read_text(encoding='utf-8', errors='replace')
    t = strip_comments(t)
    t = re.sub(r'\\footcite\b', r'\\cite', t)

    t = drop_env(t, 'tikzpicture')
    for env in ['shaded0','shaded2','shaded3','shaded4','minipage',
                'flushright','flushleft','center','wrapfig']:
        t = unwrap_env(t, env)
    for cmd in ['index','includegraphics','vspace','hspace']:
        t = drop_cmd(t, cmd)
    t = re.sub(r'\\(quad|hfill|noindent|smallskip|medskip|bigskip)\b', ' ', t)

    t = re.sub(r'\\gdf' + ARG + ARG + ARG,
               lambda m: '%s\\bigl[%s(%s)\\bigr]' % (m.group(1)[1:-1], m.group(2)[1:-1], m.group(3)[1:-1]), t)
    t = re.sub(r'\\segd' + ARG + ARG,
               lambda m: '{%s}\\circ{%s}' % (m.group(2)[1:-1], m.group(1)[1:-1]), t)
    for name, tpl in sorted(ONE_ARG.items(), key=lambda kv: -len(kv[0])):
        t = re.sub(r'\\' + name + ARG, lambda m, tpl=tpl: tpl % m.group(1)[1:-1], t)

    for name, repl in sorted(NO_ARGS.items(), key=lambda kv: -len(kv[0])):
        t = re.sub(r'\\' + name + r'\b', lambda m, repl=repl: repl, t)

    envs = '|'.join(TRIV)
    t = re.sub(r'\\begin\{(?:%s)\}%s' % (envs, OPT), r'\\begin{quote}', t)
    t = re.sub(r'\\end\{(?:%s)\}' % envs, r'\\end{quote}', t)
    t = re.sub(r'\\begin\{DESCRIPTION\}', r'\\begin{description}', t)
    t = re.sub(r'\\end\{DESCRIPTION\}', r'\\end{description}', t)

    t = re.sub(r'\\(frontmatter|mainmatter|backmatter|tableofcontents\*?|printbibliography|printindex|printglossary(\[[^\]]*\])?|nocite\{\*\})\b', '', t)

    f.write_text(t, encoding='utf-8')
print(" -> Macros expandidas y entornos saneados.")
PY

echo "[3/4] Aplanando el libro e inyectando preámbulo falso..."
MAIN_TEX="$MAIN_TEX" python3 - <<'PY'
import os, re
from pathlib import Path

main_file = Path(os.environ['MAIN_TEX'])
text = main_file.read_text(encoding='utf-8', errors='replace')

match = re.search(r'\\begin\{document\}', text)
if match:
    text = text[match.start():]

def replace_include(m):
    name = m.group(1)
    if not name.endswith('.tex'):
        name += '.tex'
    p = Path(name)
    if p.exists():
        return "\n\n" + p.read_text(encoding='utf-8', errors='replace') + "\n\n"
    return "% [Archivo %s no encontrado]" % name

text = re.sub(r'\\include\{([^}]+)\}', replace_include, text)
text = "\\documentclass{article}\n\\usepackage[utf8]{inputenc}\n" + text
main_file.write_text(text, encoding='utf-8')
print(" -> Libro aplanado.")
PY

echo "[4/4] Compilando con Pandoc..."
BIB="$(ls *.bib 2>/dev/null | head -n1 || true)"
if [ -n "$BIB" ]; then
  pandoc "$MAIN_TEX" --citeproc --bibliography="$BIB" -o "$OUTPUT_MD" --wrap=none
else
  pandoc "$MAIN_TEX" -o "$OUTPUT_MD" --wrap=none
fi

echo " -> Artefacto generado:"
ls -lh "$OUTPUT_MD"
wc -l "$OUTPUT_MD"
