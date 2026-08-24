# Rhode Island 2026 SGP TAC deck — build pipeline
#
#   make            # incremental build (cache rebuilt only if LONG data changed)
#   make force      # force-rebuild the summary cache, then figures + render
#   make cache      # (re)build the summary cache only
#   make figures    # vendor goodness-of-fit SVGs only
#   make render     # render the deck only (assumes cache + figures exist)
#   make clean      # remove rendered HTML + freeze/cache dirs (keeps summary/ + Figures/gof)
#
# Override data locations if needed:
#   make RI_LONG_DATA=/path/to/LONG.Rdata RI_GOF_ROOT=/path/to/Goodness_of_Fit

QMD      := Rhode_Island_2026_SGP_Results.qmd
HTML     := Rhode_Island_2026_SGP_Results.html
CACHE    := summary/ri_sgp_summary.rds
MANIFEST := Figures/gof/manifest.csv

export RI_LONG_DATA
export RI_GOF_ROOT

.PHONY: all force cache figures render clean

all: render

$(CACHE):
	Rscript R/01_generate_summary.R

cache: $(CACHE)

force:
	Rscript R/01_generate_summary.R --force
	$(MAKE) figures render

$(MANIFEST):
	Rscript R/02_collect_figures.R

figures: $(MANIFEST)

render: $(CACHE) $(MANIFEST)
	quarto render $(QMD) --to revealjs

clean:
	rm -f $(HTML)
	rm -rf .quarto Rhode_Island_2026_SGP_Results_files Rhode_Island_2026_SGP_Results_cache
