# Stata Code Samples

Selected Stata scripts from my work as Co-Principal Investigator and Research Manager on a randomized controlled trial of the Pentabilities socioemotional skills intervention in 40 Catalan secondary schools (4,500 students).

The full project pipeline is orchestrated by a master do-file with modular sub-scripts for data cleaning, descriptive statistics, main analysis, robustness checks, and figure generation. All paths are abstracted via global macros, allowing the same code to run across machines with different file structures.

## Scripts

### `programs_gender.do`
A library of reusable Stata programs developed for the gender gap analysis. Defines five custom programs:

- `gen_gender_binaries` — generate male/female indicator variables from a categorical gender variable
- `gen_scores_by_gender` — compute average scores within gender subgroups across five socioemotional dimensions
- `label_domains` — apply consistent labels to domain variables with a shared prefix
- `validate_merge` — diagnostic checks on merge results, with optional thresholds for expected match rates
- `validate_observations` — observation count checkpoints with optional minimum-N assertions

Demonstrates: reusable program design, defensive coding with validation checkpoints, modular Stata workflow.

### `FE_regressions.do`
Main fixed-effects regressions for the gender gap paper, examining how student gender, peer gender, and their interaction affect peer evaluations of socioemotional skills (Pentabilities).

Includes: high-dimensional fixed effects (`reghdfe`), classroom-level fixed effects, robust and clustered standard errors, multiple specifications per outcome, automated export of publication-ready LaTeX tables (full, appendix, and compact versions) using `esttab` and `file write`.

Demonstrates: end-to-end analysis-to-publication pipeline, replicable table generation, multiple comparison strategies (Peer FE vs. Student FE).

## Notes

- Data files referenced in these scripts are not included; they are project-specific and require institutional access.
- Path globals (`$cleanpb`, `$path_ol_gen`, `${gg_shared}`) are defined in upstream master and paths do-files.
- Author: Ece Yagman.
