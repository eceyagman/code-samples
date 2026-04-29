# Stata Code Samples

Selected scripts from a randomized controlled trial of the RCT intervention, where I served as Co-Principal Investigator and Research Manager.

The three files below are run in order and form one slice of a larger pipeline. Path globals (`$cleanpb`, `$path_ol_gen`, `${gg_shared}`, `$intpbobs`, `$cleanids`, `$Rclean`) are defined in upstream paths do-files.

## Scripts

### `01_master.do`
Orchestrates the full pipeline: shared cleaning, then descriptive, analysis, heterogeneity, robustness, and figure scripts. Each section is gated by a local toggle, so any subset can be re-run without rebuilding the rest.

### `02_clean_pb_observations.do`
Builds the analysis dataset by merging behavioural observations from four raters (peer, self, teacher, and external research observer) with student, observer, and teacher characteristics. Output is one row per student-by-rater-by-domain.

### `03_fe_regressions.do`
Estimates how student gender, peer gender, and their interaction shape peer evaluations across the five socioemotional domains, with classroom fixed effects and standard errors clustered at the student level. Exports full, appendix, and compact LaTeX tables.

## Notes

- Data files are not included; they are project-specific and require institutional access.
- Author: Ece Yagman.
