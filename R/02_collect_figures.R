### 02_collect_figures.R
###
### Vendors the goodness-of-fit SVGs the deck needs from the (Dropbox-symlinked)
### Goodness_of_Fit tree into Figures/gof/ using clean, grade-keyed filenames so
### (a) the Quarto deck can reference them with simple markdown image syntax,
### (b) embed-resources inlines them into a self-contained HTML, and
### (c) the figure-modal lightbox (which targets `.reveal figure img`) works.
###
### Clean name pattern:  <TOKEN>_<year>_<norm>_g<grade>.svg
###   e.g.  ELA_2025_2026_cohort_g7.svg
###         MATH_SAT_2025_2026_baseline_gEOCT.svg
### with a manifest at Figures/gof/manifest.csv.
###
### Re-run after a GoF refresh:  Rscript R/02_collect_figures.R
### Override source root with RI_GOF_ROOT.

suppressPackageStartupMessages({
  library(data.table)
})

this_dir <- tryCatch({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd()
}, error = function(e) getwd())
PROJECT_ROOT <- normalizePath(file.path(this_dir, ".."))

GOF_ROOT <- Sys.getenv(
  "RI_GOF_ROOT",
  "/Users/conet/GitHub/CenterForAssessment/Rhode_Island/master/Goodness_of_Fit"
)
DEST_ROOT <- file.path(PROJECT_ROOT, "Figures", "gof")

## content-area directory prefix -> filename subject token used inside the SVGs
CONTENT_TOKEN <- c(
  ELA             = "ELA",
  MATHEMATICS     = "MATH",
  ELA_SAT         = "ELA_SAT",
  MATHEMATICS_SAT = "MATH_SAT"
)
YEARS <- c("2022_2023", "2023_2024", "2024_2025", "2025_2026")
NORMS <- c(cohort = "", baseline = ".BASELINE")

if (!dir.exists(GOF_ROOT)) stop("GoF root not found: ", GOF_ROOT)

## Fresh output
if (dir.exists(DEST_ROOT)) unlink(list.files(DEST_ROOT, full.names = TRUE), recursive = TRUE)
dir.create(DEST_ROOT, showWarnings = FALSE, recursive = TRUE)

manifest <- list()

for (content in names(CONTENT_TOKEN)) {
  token <- CONTENT_TOKEN[[content]]
  for (year in YEARS) {
    for (norm_i in seq_along(NORMS)) {
      norm_label  <- names(NORMS)[norm_i]
      norm_suffix <- NORMS[[norm_i]]
      src_dir <- file.path(GOF_ROOT, paste0(content, ".", year, norm_suffix))
      if (!dir.exists(src_dir)) next

      svgs <- list.files(src_dir, pattern = "\\.svg$", full.names = TRUE)
      if (!length(svgs)) next

      ## Parse grade from the leading "<year>_<token>_<grade>" segment.
      lead  <- sub(";.*$", "", basename(svgs))
      grade <- sub(paste0("^", year, "_", token, "_"), "", lead)

      ## When a directory holds two variants of the same current grade (an
      ## extra deeper-history file), keep the one with the longest progression.
      n_seg <- lengths(regmatches(basename(svgs), gregexpr(";", basename(svgs))))
      keep  <- vapply(split(seq_along(grade), grade), function(idx) {
        idx[which.max(n_seg[idx])]
      }, integer(1))

      for (i in keep) {
        g <- grade[i]
        clean <- paste0(token, "_", year, "_", norm_label, "_g", g, ".svg")
        dest  <- file.path(DEST_ROOT, clean)
        if (file.copy(svgs[i], dest, overwrite = TRUE)) {
          manifest[[length(manifest) + 1L]] <- data.table(
            content_area = content,
            token        = token,
            year         = year,
            norm         = norm_label,
            grade        = g,
            file         = clean,
            rel_path     = file.path("Figures", "gof", clean),
            source_file  = basename(svgs[i])
          )
        }
      }
    }
  }
}

if (!length(manifest)) stop("No GoF SVGs copied; check GOF_ROOT: ", GOF_ROOT)

manifest_dt <- rbindlist(manifest)
setorder(manifest_dt, content_area, year, norm, grade)
fwrite(manifest_dt, file.path(DEST_ROOT, "manifest.csv"))

message("Copied ", nrow(manifest_dt), " GoF SVGs into ", DEST_ROOT)
message("Manifest: ", file.path(DEST_ROOT, "manifest.csv"))
