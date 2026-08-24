#!/usr/bin/env bash
#
# Build the Rhode Island 2026 SGP TAC deck end-to-end.
#
#   1. Regenerate the compact summary cache from the LONG data (once).
#   2. Vendor the goodness-of-fit SVGs the deck references.
#   3. Render the self-contained reveal.js HTML.
#
# Usage:
#   ./render.sh                 # incremental: rebuild cache only if data changed
#   ./render.sh --force         # force cache + figure rebuild, then render
#
# Data / GoF locations may be overridden with environment variables:
#   RI_LONG_DATA   path to Rhode_Island_SGP_LONG_Data.Rdata
#   RI_GOF_ROOT    path to the Goodness_of_Fit directory
#
set -euo pipefail

cd "$(dirname "$0")"

FORCE=""
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  FORCE="--force"
fi

echo "==> [1/3] Generating summary cache"
Rscript R/01_generate_summary.R ${FORCE}

echo "==> [2/3] Collecting goodness-of-fit figures"
Rscript R/02_collect_figures.R

echo "==> [3/3] Rendering deck"
quarto render Rhode_Island_2026_SGP_Results.qmd --to revealjs
mkdir -p docs
mv -f index.html docs/index.html
rm -rf index_files            # self-contained deck; supporting dir not needed

echo "==> Done: docs/index.html (GitHub Pages: serve from /docs)"
