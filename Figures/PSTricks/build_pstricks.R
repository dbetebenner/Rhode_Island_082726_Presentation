###############################################################################
### build_pstricks.R -- Build the PSTricks schematic for the RIDE TAC deck.
###
### Mirrors the compile chain used in
###   Copula_Sensitivity_Analyses/STEP_3_LIwLD/Figures/Analytic_Explanation/
###
###   latex -> dvips -E -> gs            (PDF, for print / the paper)
###   dvisvgm on the DVI                 (SVG, for the reveal.js deck)
###
### PSTricks emits PostScript specials, so the DVI route (not pdflatex) is
### required. dvisvgm is run on the DVI rather than the PS because the DVI
### carries TeX-native font metadata; Homebrew dvisvgm additionally needs
### TEXMFCNF/TEXMFDIST exported so the PostScript headers resolve.
###
### Usage (from this directory):
###   Rscript build_pstricks.R
###
### Outputs land in ../ (Figures/), which is what the deck references.
###############################################################################

FIGURES <- c("sgp_cdf_identity")

this_dir <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
setwd(this_dir)
out_dir <- normalizePath(file.path(this_dir, ".."), mustWork = TRUE)

for (bin in c("latex", "dvips", "gs", "pdfcrop", "pdf2svg")) {
  if (Sys.which(bin) == "") stop("Required binary not found on PATH: ", bin)
}

## Homebrew dvisvgm cannot locate texmf.cnf unaided; resolve it as the
## Analytic_Explanation build does.
texmf_dist <- Sys.getenv("TEXMFDIST", unset = "")
if (!nzchar(texmf_dist) && nzchar(Sys.which("kpsewhich"))) {
  k <- suppressWarnings(system2("kpsewhich", "texmf.cnf", stdout = TRUE, stderr = FALSE))
  if (length(k) && nzchar(k[1])) {
    texmf_dist <- normalizePath(file.path(dirname(k[1]), ".."), mustWork = FALSE)
  }
}
dvisvgm_env <- if (nzchar(texmf_dist)) {
  sprintf("export TEXMFCNF=%s/web2c && export TEXMFDIST=%s && ", texmf_dist, texmf_dist)
} else ""

## PSTricks draws upward from the TeX reference point and dvips cannot measure
## PostScript specials, so `dvips -E` yields a degenerate BoundingBox and any
## hard-coded box goes stale the moment the figure is edited. Instead each .tex
## uses a generous canvas and the build crops to the real ink afterwards with
## pdfcrop. (Translating the content with `gs -c ... translate` does not work:
## dvips output re-establishes the CTM, discarding the translation.)

CANVAS   <- c(width_in = 17, height_in = 8)   # must match the .tex geometry
MARGIN   <- 5                                 # points of whitespace kept

build_one <- function(name) {
  cat(sprintf("  [PSTricks] %s ...", name))

  if (system2("latex", c("-interaction=nonstopmode", name),
              stdout = FALSE, stderr = FALSE) != 0) {
    cat(sprintf(" FAIL (latex); see %s.log\n", name)); return(FALSE)
  }

  ps <- paste0(name, ".ps"); full <- paste0(name, "_full.pdf")
  pdf <- paste0(name, ".pdf"); svg <- paste0(name, ".svg")

  system2("dvips", c("-T", sprintf("%gin,%gin", CANVAS[["width_in"]], CANVAS[["height_in"]]),
                     name, "-o", ps), stdout = FALSE, stderr = FALSE)
  if (!file.exists(ps)) { cat(" FAIL (dvips)\n"); return(FALSE) }

  msg <- system2("gs",
    c("-q", "-dALLOWPSTRANSPARENCY", "-dBATCH", "-dNOPAUSE", "-dFIXEDMEDIA",
      sprintf("-dDEVICEWIDTHPOINTS=%g", 72 * CANVAS[["width_in"]]),
      sprintf("-dDEVICEHEIGHTPOINTS=%g", 72 * CANVAS[["height_in"]]),
      "-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.4",
      paste0("-sOutputFile=", full), ps),
    stdout = TRUE, stderr = TRUE)
  if (!file.exists(full)) { cat(" FAIL (gs)\n"); return(FALSE) }
  ## A PostScript error still leaves a valid but blank PDF, so treat any
  ## ghostscript diagnostic as a failure rather than shipping an empty figure.
  if (length(msg) && any(grepl("Error|stackunderflow|undefined", msg))) {
    cat(sprintf(" FAIL (PostScript: %s)\n", msg[1])); return(FALSE)
  }

  if (system2("pdfcrop", c("--margins", MARGIN, full, pdf),
              stdout = FALSE, stderr = FALSE) != 0 || !file.exists(pdf)) {
    cat(" FAIL (pdfcrop)\n"); return(FALSE)
  }

  if (file.exists(svg)) file.remove(svg)
  if (system2("pdf2svg", c(pdf, svg), stdout = FALSE, stderr = FALSE) != 0 ||
      !file.exists(svg) || file.size(svg) < 5000) {
    cat(" FAIL (pdf2svg produced no content)\n"); return(FALSE)
  }

  file.copy(pdf, file.path(out_dir, pdf), overwrite = TRUE)
  file.copy(svg, file.path(out_dir, svg), overwrite = TRUE)
  cat(sprintf(" OK (svg %s bytes, pdf %s bytes)\n",
              format(file.size(svg), big.mark = ","),
              format(file.size(pdf), big.mark = ",")))
  TRUE
}

cat("\n=== PSTricks figure build ===\n  out:", out_dir, "\n")
ok <- vapply(FIGURES, build_one, logical(1))

## Clean intermediates, keep sources
unlink(list.files(".", pattern = "\\.(aux|log|dvi|ps)$|_full\\.pdf$", full.names = TRUE))

if (!all(ok)) stop("One or more figures failed to build.")
cat("Done.\n")
