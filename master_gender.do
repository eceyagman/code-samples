********************************************************************************
*                    MASTER DO FILE - GENDER GAP PAPER                         *
********************************************************************************
/*
* Purpose:        Run all analyses for the Gender Gap paper
* Last modified:  26/01/2026
*
* PAPER FOCUS:    Gender gaps in peer evaluations of socioemotional skills
*
* WORKFLOW:
*   1. Setup - Load paths and programs
*   2. Data Cleaning - Run shared cleaning files (if needed)
*   3. Descriptive Statistics - Balance tables, summary stats, figures
*   4. Main Analysis - Fixed effects regressions
*   5. Heterogeneity - By cycle, score levels, etc.
*   6. Robustness - Alternative specifications
*   7. Figures - Coefficient plots and visualizations
*
* OUTPUTS:
*   - Tables exported to $path_ol_gen/tables/
*   - Figures exported to $path_ol_gen/figures/
*
* DATASETS USED:
*   - $cleanpb/class/pb_4s_all_new.dta (main PB observations)
*   - $cleangender/bessi_el.dta (BESSI endline)
*   - $cleanfapb/pb_3s_new.dta (FA observations)
*/
********************************************************************************

clear all
set more off


********************************************************************************
*                    1. SETUP                                                  *
********************************************************************************

* Load gender gap paths and programs
do "${analysis}/gender gap/00_shared/paths_gender.do"

* Verify key paths exist
assert "${path_ol_gen}" != ""

di as text _n "========================================"
di as text "  GENDER GAP PAPER - MASTER DO FILE"
di as text "========================================"
di as text "Output path: ${path_ol_gen}"
di as text ""

********************************************************************************
*                    2. DATA CLEANING (Shared)                                 *
********************************************************************************

local run_cleaning = 0  // Set to 1 to re-run data cleaning

if `run_cleaning' == 1 {
    di as text "Running data cleaning..."

    * PB observations cleaning (main dataset)
    do "${gg_shared_clean}/datap_pbobs_cleaning_4s_new.do"

    * BESSI cleaning
    do "${gg_shared_clean}/datap_bessi_cleaning_new.do"

    * FA cleaning
    do "${gg_shared_clean}/datap_fa_cleaning_new.do"

    di as text "Data cleaning complete."
}

********************************************************************************
*                    3. DESCRIPTIVE STATISTICS                                 *
********************************************************************************

local run_descriptive = 1  // Set to 1 to run

if `run_descriptive' == 1 {
    di as text _n "Running descriptive analyses..."

    * Balance tables
    do "${gg_p1_desc}/balance_gender.do"

    * Summary statistics
    do "${gg_p1_desc}/desc_sumstat.do"

    * Teacher and EO descriptives
    do "${gg_p1_desc}/desc_tchEO.do"

    * Descriptive figures
    do "${gg_p1_figures}/desc_fig.do"

    di as text "Descriptive analyses complete."
}

********************************************************************************
*                    4. MAIN ANALYSIS                                          *
********************************************************************************

local run_main = 1  // Set to 1 to run

if `run_main' == 1 {
    di as text _n "Running main analyses..."

    * Main FE regressions (peer and self evaluations)
    do "${gg_p1_analysis}/FE_regressions.do"

    * BESSI peer evaluations
    do "${gg_p1_analysis}/analysis_bessi_peer_gen.do"

    * BESSI self evaluations
    do "${gg_p1_analysis}/analysis_bessi_self_gen.do"

    di as text "Main analyses complete."
}

********************************************************************************
*                    5. HETEROGENEITY                                          *
********************************************************************************

local run_hetero = 1  // Set to 1 to run

if `run_hetero' == 1 {
    di as text _n "Running heterogeneity analyses..."

    * Heterogeneity tables
    do "${gg_p1_hetero}/Heterogen_tables.do"

    * Heterogeneity by score
    do "${gg_p1_hetero}/Heterogen_score.do"

    * Heterogeneity coefficient plots
    do "${gg_p1_hetero}/Heterogen_coefplots.do"

    * Mechanism analysis (female teacher %)
    do "${gg_p1_hetero}/Mechanism.do"

    * Self-evaluation heterogeneity by student background (CO, BESSI, FA)
    do "${gg_p1_hetero}/selfeval_heterogeneity.do"

    * Self-evaluation consequences: does self-assessment predict GPA/absences?
    do "${gg_p1_hetero}/selfeval_consequences.do"

    di as text "Heterogeneity analyses complete."
}

********************************************************************************
*                    5B. FRIENDSHIP MEDIATION ANALYSIS                         *
********************************************************************************

local run_friendship = 1  // Set to 1 to run

if `run_friendship' == 1 {
    di as text _n "Running friendship-gender mediation analysis..."

    * Create output folder if it doesn't exist
    capture mkdir "$path_ol_gen/tables/friendship"

    * First, create friendship indicators (if not already done)
    * Uncomment the line below if you need to regenerate the friendship data:
    * do "${gg_shared_clean}/create_friendship_indicators.do"

    * Run friendship-gender analysis
    do "${gg_p1_analysis}/friendship/analysis_friendship_gender.do"

    di as text "Friendship analysis complete."
}

********************************************************************************
*                    5C. GROUP COMPOSITION CHECK                                *
********************************************************************************

local run_group_check = 1  // Set to 1 to run

if `run_group_check' == 1 {
    di as text _n "Checking for gender homophily in group formation..."

    * Run group composition diagnostic
    do "${gg_p1_analysis}/check_group_composition.do"

    di as text "Group composition check complete."
}

********************************************************************************
*                    6. ROBUSTNESS                                             *
********************************************************************************

local run_robust = 1  // Set to 1 to run

if `run_robust' == 1 {
    di as text _n "Running robustness checks..."

    * Main robustness
    do "${gg_p1_robust}/Robustness.do"

    * Teacher FE analysis
    do "${gg_p1_robust}/Teacher_FE.do"

    * Panel analysis
    do "${gg_p1_robust}/Panel.do"

    * Regressions by teacher gender
    do "${gg_p1_robust}/FE_reg_F_vs_M_tch.do"

    di as text "Robustness checks complete."
}

********************************************************************************
*                    7. FIGURES                                                *
********************************************************************************

local run_figures = 1  // Set to 1 to run

if `run_figures' == 1 {
    di as text _n "Creating figures..."

    * Coefficient plots
    do "${gg_p1_figures}/Coefplots_self_peer.do"

    di as text "Figures complete."
}

********************************************************************************
di as text _n "========================================"
di as text "  GENDER GAP PAPER - COMPLETE"
di as text "========================================"
********************************************************************************
