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

def _balanced(t, b):
    depth = 0
    j = b
    while j < len(t):
        if t[j] == '{':
            depth += 1
        elif t[j] == '}':
            depth -= 1
            if depth == 0:
                break
        j += 1
    return j

def unwrap_box(t, cmd):
    i = 0
    out = []
    while True:
        m = re.search(r'\\%s(?:\s+to\s+[^{]*)?\s*\{' % cmd, t[i:])
        if not m:
            out.append(t[i:])
            break
        s = i + m.start()
        b = i + m.end() - 1
        j = _balanced(t, b)
        out.append(t[i:s])
        out.append(t[b + 1:j])
        i = j + 1
    return ''.join(out)

def unwrap_mathhbox(t):
    i = 0
    out = []
    while True:
        m = re.search(r'\$\$\s*\\(?:h|v)box(?:\s+to\s+[^{]*)?\s*\{', t[i:])
        if not m:
            out.append(t[i:])
            break
        s = i + m.start()
        b = i + m.end() - 1
        j = _balanced(t, b)
        if t[j + 1:j + 3] == '$$':
            out.append(t[i:s])
            out.append(t[b + 1:j])
            i = j + 3
        else:
            out.append(t[i:j + 1])
            i = j + 1
    return ''.join(out)

def harden_math(t):
    def fixseg(seg):
        seg = re.sub(r'\\cr\b', r'\\\\', seg)
        seg = re.sub(r'\$([^$]+)\$', r'\1', seg)
        return seg
    def fixenv(m):
        if m.group(1) in ('align', 'align*', 'aligned', 'eqnarray', 'eqnarray*',
                          'array', 'cases', 'split'):
            return fixseg(m.group(0))
        return m.group(0)
    t = re.sub(r'\\begin\{([a-zA-Z*]+)\}.*?\\end\{\1\}', fixenv, t, flags=re.S)
    t = re.sub(r'\\\[[\s\S]*?\\\]', lambda m: fixseg(m.group(0)), t)
    t = re.sub(r'\$\$[\s\S]*?\$\$', lambda m: fixseg(m.group(0)), t)
    return t

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
    t = unwrap_mathhbox(t)
    for cmd in ['hbox', 'vbox']:
        t = unwrap_box(t, cmd)
    t = re.sub(r'\\raisebox(?:\[[^\]]*\])?\s*\{[^{}]*\}', '', t)
    # --- Etiquetas decorativas, condicionales y escapes Unicode de TeX ---
    t = re.sub(r'\\tag\*?' + NESTED2, '', t)
    t = re.sub(r'\\ifmmode.*?\\fi', '', t, flags=re.S)
    t = re.sub(r'\^\^\^\^([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), t)
    t = harden_math(t)    
    t = harden_math(t)
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
preamble = text[:match.start()] if match else ''
body = text[match.start():] if match else text

ARG = r'(\{(?:[^{}]|{(?:[^{}]|{[^{}]*})*})*\})'

def extract_brace(s, i):
    depth = 0
    for j in range(i, len(s)):
        if s[j] == '{':
            depth += 1
        elif s[j] == '}':
            depth -= 1
            if depth == 0:
                return s[i + 1:j]
    return None

# ---- Macros sin argumentos ----
defs = {}
pat = r'\\(?:re)?newcommand\*?\s*(?:\{\\([a-zA-Z@]+)\}|\\([a-zA-Z@]+))\s*(\[[^\]]*\])*\s*\{'
for m in re.finditer(pat, preamble):
    if m.group(3):
        continue
    name = m.group(1) or m.group(2)
    repl = extract_brace(preamble, m.end() - 1)
    if repl is not None:
        defs[name] = repl
for m in re.finditer(r'\\def\s*\\([a-zA-Z@]+)\s*\{', preamble):
    repl = extract_brace(preamble, m.end() - 1)
    if repl is not None:
        defs[m.group(1)] = repl
for m in re.finditer(r'\\let\s*\\([a-zA-Z@]+)\s*=?\s*\\([a-zA-Z@]+)', preamble):
    defs[m.group(1)] = '\\' + m.group(2)

# ---- Macros con UN argumento ----
defs1 = {}
pat1 = r'\\(?:re)?newcommand\*?\s*(?:\{\\([a-zA-Z@]+)\}|\\([a-zA-Z@]+))\s*\[\d+\]\s*\{'
for m in re.finditer(pat1, preamble):
    name = m.group(1) or m.group(2)
    tpl = extract_brace(preamble, m.end() - 1)
    if tpl is not None and '#1' in tpl:
        defs1[name] = tpl
for m in re.finditer(r'\\def\s*\\([a-zA-Z@]+)\s*#\d+\s*\{', preamble):
    tpl = extract_brace(preamble, m.end() - 1)
    if tpl is not None and '#1' in tpl:
        defs1[m.group(1)] = tpl

def replace_include(m):
    name = m.group(1)
    if not name.endswith('.tex'):
        name += '.tex'
    p = Path(name)
    if p.exists():
        return "\n\n" + p.read_text(encoding='utf-8', errors='replace') + "\n\n"
    return "% [Archivo %s no encontrado]" % name

for _ in range(10):
    new = re.sub(r'\\include\{([^}]+)\}', replace_include, body)
    if new == body:
        break
    body = new

# ---- Expandir macros cosechadas (2 pasadas) ----
for _ in range(2):
    for name, repl in sorted(defs.items(), key=lambda kv: -len(kv[0])):
        body = re.sub(r'\\' + name + r'\b', lambda m, r=repl: r, body)
    for name, tpl in sorted(defs1.items(), key=lambda kv: -len(kv[0])):
        body = re.sub(r'\\' + name + ARG, lambda m, t=tpl: t.replace('#1', m.group(1)[1:-1]), body)
        body = re.sub(r'\\' + name + r'(?![a-zA-Z@])\s*([^\s\\{}%])',
                      lambda m, t=tpl: t.replace('#1', m.group(1)), body)

body = "\\documentclass{article}\n\\usepackage[utf8]{inputenc}\n" + body
main_file.write_text(body, encoding='utf-8')
print(" -> Libro aplanado (%d macros sin arg + %d con 1 arg cosechadas)." % (len(defs), len(defs1)))
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
