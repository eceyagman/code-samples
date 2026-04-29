********************************************************************************
*                       Gender Gap Main Regressions                            *
********************************************************************************
/*
    TITLE:          FE regressions.do

    PURPOSE:        Run fixed effects regressions analyzing gender gaps in
                    self-evaluations and peer-evaluations of pentabilities
                    (soft skills). Examines how student gender, peer gender,
                    and their interactions affect score assignments.

    AUTHOR:         Ece Yagman
    DATE CREATED:   10.03.2025
    LAST UPDATED:   09.02.2026

    DEPENDENCIES:
        - estout (for esttab)
        - reghdfe (for high-dimensional fixed effects)

    INPUTS:
        - $cleanpb/class/pb_4s_all_new.dta (main analysis dataset)
        - ${pathgit}/cat/code/analysis/gender gap/third paper/analysis_dataprep.do

    OUTPUTS:
        - $path_ol_gen/tables/self_`out'_full.tex (self-evaluation tables)
        - $path_ol_gen/tables/self_`out'_appendix.tex
        - $path_ol_gen/tables/self_compact.tex
        - $path_ol_gen/tables/ES1_`out'_full.tex (peer-evaluation tables)
        - $path_ol_gen/tables/ES1_`out'_appendix.tex
        - $path_ol_gen/tables/peer_compact.tex
        - $path_ol_gen/tables/FE_5domains.tex

    STRUCTURE:
        2. Self-Evaluations Analysis
            2.1 Full specification by domain
            2.2 Compact specification (all 5 domains)
        3. Peer-Evaluations Analysis
            3.1 Full specification by domain
            3.2 Compact specification (all 5 domains)
            3.3 Student FE vs Peer FE comparison

    NOTES:
        - All regressions use classroom fixed effects
        - Standard errors clustered at student level for peer evaluations
        - Robust standard errors for self evaluations
*/



********************************************************************************
*                        2. SELF-EVALUATIONS ANALYSIS                          *
********************************************************************************

*------------------------------------------------------------------------------*
* 2.1 Full specification: cluster at individual level with classroom FE
*------------------------------------------------------------------------------*

use "$cleanpb/class/pb_4s_all_new.dta", clear
do "${gg_shared}/analysis_dataprep.do"

* Keep only SELF evaluations
keep if pb_type == "SELF"


foreach out in $PB_out {

    * Get the variable label; if missing, use the variable name
    local lvar : variable label s_std_`out'
    if "`lvar'" == "" {
        local lvar "`out'"
    }

    *-------------------------------------------*
    * Run regressions and store estimates
    *-------------------------------------------*

    eststo clear

    local classroom_fe "Yes"
    local stu_control "Yes"

    * Regression 1: Student controls
    areg s_std_`out' stu_fem $controls_spain_s $controls_univ_cat_s, robust absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    eststo Model1

    * Regression 2: Teacher Score + Student controls
    areg s_std_`out' stu_fem tch_`out' $controls_spain_s $controls_univ_cat_s, robust absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    eststo Model2

    * Regression 3: Teacher Score + Student controls + Average Peer Score
    areg s_std_`out' stu_fem tch_`out' ave_peer_`out' $controls_spain_s $controls_univ_cat_s, robust absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    eststo Model3

    *-------------------------------------------*
    * Export Results: Main Table
    *-------------------------------------------*

    local outfile "$path_ol_gen/tables/self_`out'_full.tex"

    esttab Model1 Model2 Model3 using "`outfile'", ///
        replace ///
        b(%9.3f) se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(stu_control classroom_fe r2_a N, ///
              labels("Student Background Controls" "Classroom FE" "R-squared" "Observations") ///
              fmt(%9.0f %9.0f %9.3f %9.0f)) ///
        substitute("\_" "_") ///
        keep(stu_fem tch_`out' ave_peer_`out') ///
        alignment(D{.}{.}{-1}) ///
        nogap compress label ///
        coeflabels("stu_fem" "Female Student") ///
        nomtitles booktabs ///
        order(stu_fem tch_`out' ave_peer_`out') ///
        prehead("\begin{table}[h!]" ///
            "\centering" ///
            "\small" ///
            "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
            "\begin{threeparttable}" ///
            "\caption{\label{tab:self_`out'}Self-Assigned Score - `lvar'}" ///
            "\begin{tabular}{l*{3}{D{.}{.}{-1}}}" ///
            "\toprule") ///
        postfoot("\bottomrule" ///
            "\end{tabular}" ///
            "\begin{tablenotes}[flushleft]" ///
            "\footnotesize" ///
            "\item Note: Robust standard errors in parentheses. \sym{*} (p<0.10), \sym{**} (p<0.05), \sym{***} (p<0.01).\\" ///
            "\end{tablenotes}" ///
            "\end{threeparttable}" ///
            "\end{table}")

    *-------------------------------------------*
    * Export Results: Appendix Table (with all controls)
    *-------------------------------------------*

    local outfile "$path_ol_gen/tables/self_`out'_appendix.tex"

    esttab Model1 Model2 Model3 using "`outfile'", ///
        replace ///
        b(%9.3f) se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(classroom_fe r2 N, ///
              labels("Classroom FE" "R-squared" "Observations") ///
              fmt(%9.0f %9.3f %9.0f)) ///
        substitute("\_" "_") ///
        keep(stu_fem tch_`out' ave_peer_`out' stu_spain stu_cg1_spain stu_cg2_spain ///
             1.stu_cg1_univ_cat 1.stu_cg2_univ_cat ///
             3.stu_cg1_univ_cat 3.stu_cg2_univ_cat ///
             _cons) ///
        alignment(D{.}{.}{-1}) ///
        nogap compress label ///
        coeflabels("stu_fem" "Female Student" ///
            "1.stu_cg1_univ_cat" "Stu CG1 went to uni" ///
            "3.stu_cg1_univ_cat" "Stu CG1 uni edu not known" ///
            "1.stu_cg2_univ_cat" "Stu CG2 went to uni" ///
            "3.stu_cg2_univ_cat" "Stu CG2 uni edu not known" ///
            _cons "Constant") ///
        nomtitles booktabs ///
        order(stu_fem tch_`out' ave_peer_`out') ///
        prehead("\begin{table}[h!]" ///
            "\centering" ///
            "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
            "\caption{\label{tab:self_`out'_appendix}Self-Assigned Score - `lvar'}" ///
            "\resizebox{0.9\textwidth}{!}{" ///
            "\begin{tabular}{l*{3}{D{.}{.}{-1}}}" ///
            "\toprule") ///
        postfoot("\bottomrule" ///
            "\multicolumn{4}{l}{\footnotesize Note: Robust standard errors in parentheses. \sym{*} (p<0.10), \sym{**} (p<0.05), \sym{***} (p<0.01).}\\" ///
            "\end{tabular}" ///
            "}" ///
            "\end{table}")
}


*------------------------------------------------------------------------------*
* 2.2 Compact specification: all 5 domains in one table
*------------------------------------------------------------------------------*

use "$cleanpb/class/pb_4s_all_new.dta", clear
do "${gg_shared}/analysis_dataprep.do"

* Keep only SELF evaluations
keep if pb_type == "SELF"


* Initialize LaTeX row macros
local row_fem      "Female Student"
local row_fem_se   ""
local row_tch      "Teacher Score"
local row_tch_se   ""
local row_peer     "Average Peer Score"
local row_peer_se  ""
local row_N        "Observations"
local row_r2       "Adj. R-squared"

foreach out in $PB_out {

    * Run regression
    areg s_std_`out' ///
        stu_fem ///
        tch_`out' ///
        ave_peer_`out' ///
        $controls_spain_s $controls_univ_cat_s, robust absorb(class_fixed)

    * Extract coefficients from r(table)
    matrix b = r(table)

    * Female student coefficient
    local fem_coef : display %05.3f b[1, 1]
    local fem_se   : display %05.3f b[2, 1]
    local fem_pval : display %05.3f b[4, 1]

    * Teacher score coefficient
    local tch_coef : display %05.3f b[1, 2]
    local tch_se   : display %05.3f b[2, 2]
    local tch_pval : display %05.3f b[4, 2]

    * Peer score coefficient
    local peer_coef : display %05.3f b[1, 3]
    local peer_se   : display %05.3f b[2, 3]
    local peer_pval : display %05.3f b[4, 3]

    * Sample size and R-squared
    local N : display %5.0f e(N)
    local r2 : display %5.3f e(r2_a)

    * Add significance stars
    local plist "fem tch peer"
    foreach w in `plist' {
        local `w'_star ""
        if ``w'_pval' <= 0.01 {
            local `w'_star "***"
        }
        else if ``w'_pval' <= 0.05 {
            local `w'_star "**"
        }
        else if ``w'_pval' <= 0.1 {
            local `w'_star "*"
        }
    }

    * Build coefficient strings with stars
    local fem_col  "`fem_coef'`fem_star'"
    local fem_secol "(`fem_se')"
    local tch_col  "`tch_coef'`tch_star'"
    local tch_secol "(`tch_se')"
    local peer_col "`peer_coef'`peer_star'"
    local peer_secol "(`peer_se')"

    * Append to row macros
    local row_fem      "`row_fem' & `fem_col'"
    local row_fem_se   "`row_fem_se' & `fem_secol'"
    local row_tch      "`row_tch' & `tch_col'"
    local row_tch_se   "`row_tch_se' & `tch_secol'"
    local row_peer     "`row_peer' & `peer_col'"
    local row_peer_se  "`row_peer_se' & `peer_secol'"
    local row_N        "`row_N' & `N'"
    local row_r2       "`row_r2' & `r2'"
}

* Finalize rows with line endings
local row_fem      "`row_fem' \\"
local row_fem_se   "`row_fem_se' \\"
local row_tch      "`row_tch' \\"
local row_tch_se   "`row_tch_se' \\"
local row_peer     "`row_peer' \\"
local row_peer_se  "`row_peer_se' \\"
local row_N        "`row_N' \\"
local row_r2       "`row_r2' \\"

* Write compact table to file
cap file close fh
file open fh using "$path_ol_gen/tables/self_compact.tex", write replace

file write fh _n "\begin{table}[htp]"
file write fh _n "\centering"
file write fh _n "\resizebox{0.95\textwidth}{!}{"
file write fh _n "\begin{threeparttable}"
file write fh _n "\caption{Self-Assigned Score: All 5 dimensions}"
file write fh _n "\label{tab:self_compact}"
file write fh _n "\begin{tabular}{lccccc}"
file write fh _n "\toprule"
file write fh _n " & Autonomy & Cooperation & Responsibility & Emotion  & Thinking \\"
file write fh _n "\midrule"

file write fh _n "`row_fem'"
file write fh _n "`row_fem_se'"
file write fh _n "`row_tch'"
file write fh _n "`row_tch_se'"
file write fh _n "`row_peer'"
file write fh _n "`row_peer_se'"

file write fh _n "\midrule"
file write fh _n "`row_N'"
file write fh _n "`row_r2'"

file write fh _n "\bottomrule"
file write fh _n "\end{tabular}"
file write fh _n "\begin{tablenotes}[flushleft]"
file write fh _n "\footnotesize"
file write fh _n "\item Note: All regressions control for student background characteristics and classroom fixed effects. Robust standard errors are in parentheses. The dependent variable is self-assigned score. *p<0.10, ** p<0.05, *** p<0.010."
file write fh _n "\end{tablenotes}"
file write fh _n "\end{threeparttable}"
file write fh _n "}"
file write fh _n "\end{table}"

file close fh


********************************************************************************
*                        3. PEER-EVALUATIONS ANALYSIS                          *
********************************************************************************

*------------------------------------------------------------------------------*
* 3.1 Full specification by domain
*------------------------------------------------------------------------------*

use "$cleanpb/class/pb_4s_all_new.dta", clear
do "${gg_shared}/analysis_dataprep.do"

* Keep only PEER evaluations
keep if pb_type == "CO"


foreach out in $PB_out {

    * Get the variable label; if missing, use the variable name
    local lvar : variable label s_std_`out'
    if "`lvar'" == "" {
        local lvar "`out'"
    }

    *-------------------------------------------*
    * Run regressions and store estimates
    *-------------------------------------------*

    eststo clear

    local classroom_fe "Yes"
    local stu_control "Yes"
    local peer_control "Yes"

    * Regression 1: Student controls + Peer controls
    areg s_std_`out' $gendervar $controls_spain_s $controls_univ_cat_s $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    estadd local peer_control `"`peer_control'"'
    eststo Model1

    * Compute Female Student + Female Peer effect
    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    estadd scalar FemFem = r(estimate)
    estadd scalar FemFemP = r(p)

    * Regression 2: Peer's Self Score + Student controls + Peer controls
    areg s_std_`out' obs_self_`out' $gendervar $controls_spain_s $controls_univ_cat_s $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    estadd local peer_control `"`peer_control'"'
    eststo Model2

    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    estadd scalar FemFem = r(estimate)
    estadd scalar FemFemP = r(p)

    * Regression 3: Teacher Score + Peer's Self Score + Student controls + Peer controls
    areg s_std_`out' tch_`out' obs_self_`out' $gendervar $controls_spain_s $controls_univ_cat_s $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    estadd local peer_control `"`peer_control'"'
    eststo Model3

    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    estadd scalar FemFem = r(estimate)
    estadd scalar FemFemP = r(p)

    * Regression 4: Student self score + Teacher Score + Peer's Self Score + controls
    areg s_std_`out' self_`out' tch_`out' obs_self_`out' $gendervar $controls_spain_s $controls_univ_cat_s $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    estadd local peer_control `"`peer_control'"'
    eststo Model4

    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    estadd scalar FemFem = r(estimate)
    estadd scalar FemFemP = r(p)

    * Regression 5: Peer's Teacher score + Student self score + Teacher Score + Peer's Self Score + controls
    areg s_std_`out' obs_tch_`out' self_`out' tch_`out' obs_self_`out' $gendervar $controls_spain_s $controls_univ_cat_s $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(class_fixed)
    estadd local classroom_fe `"`classroom_fe'"'
    estadd local stu_control `"`stu_control'"'
    estadd local peer_control `"`peer_control'"'
    eststo Model5

    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    estadd scalar FemFem = r(estimate)
    estadd scalar FemFemP = r(p)

    *-------------------------------------------*
    * Export Results: Appendix Table
    *-------------------------------------------*

    local outfile "$path_ol_gen/tables/ES1_`out'_appendix.tex"

    esttab Model1 Model2 Model3 Model4 Model5 using "`outfile'", ///
        replace ///
        b(%9.3f) se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(FemFem FemFemP classroom_fe r2 N, ///
              labels("Fem Peer: Fem vs Male Stu ($\beta_1 + \beta_3$)" "Fem Peer: P-val" "Classroom FE" "R-squared" "Observations") ///
              fmt(%9.3f %9.3f %9.0f %9.3f %9.0f)) ///
        substitute("\_" "_") ///
        keep(tch_`out' obs_tch_`out' obs_self_`out' self_`out' 1.stu_fem 1.obs_fem 1.stu_fem#1.obs_fem ///
             stu_spain stu_cg1_spain stu_cg2_spain obs_spain obs_cg1_spain obs_cg2_spain ///
             1.stu_cg1_univ_cat 1.stu_cg2_univ_cat 1.obs_cg1_univ_cat 1.obs_cg2_univ_cat ///
             3.stu_cg1_univ_cat 3.stu_cg2_univ_cat 3.obs_cg1_univ_cat 3.obs_cg2_univ_cat ///
             _cons) ///
        alignment(D{.}{.}{-1}) ///
        nogap compress label ///
        coeflabels( ///
            "1.stu_fem" "Female Student ($\beta_1$)" ///
            "1.obs_fem" "Female Peer ($\beta_2$)" ///
            "1.stu_fem#1.obs_fem" "Female Student x Female Peer ($\beta_3$)" ///
            "1.stu_cg1_univ_cat" "Stu CG1 went to uni" ///
            "3.stu_cg1_univ_cat" "Stu CG1 uni edu not known" ///
            "1.stu_cg2_univ_cat" "Stu CG2 went to uni" ///
            "3.stu_cg2_univ_cat" "Stu CG2 uni edu not known" ///
            "1.obs_cg1_univ_cat" "Peer CG1 went to uni" ///
            "3.obs_cg1_univ_cat" "Peer CG1 uni edu not known" ///
            "1.obs_cg2_univ_cat" "Peer CG2 went to uni" ///
            "3.obs_cg2_univ_cat" "Peer CG2 uni edu not known" ///
            _cons "Constant") ///
        nomtitles booktabs ///
        order(1.stu_fem 1.obs_fem 1.stu_fem#1.obs_fem obs_self_`out' tch_`out' self_`out' obs_tch_`out') ///
        prehead("\begin{table}[h!]" ///
            "\centering" ///
            "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
            "\caption{\label{tab:ES1_`out'_appendix}Peer-Assigned Score - `lvar'}" ///
            "\resizebox{0.9\textwidth}{!}{" ///
            "\begin{tabular}{l*{5}{D{.}{.}{-1}}}" ///
            "\toprule") ///
        postfoot("\bottomrule" ///
            "\multicolumn{5}{l}{\footnotesize Standard errors in parentheses and clustered at student level. \sym{*} (p<0.10), \sym{**} (p<0.05), \sym{***} (p<0.01).}\\" ///
            "\end{tabular}" ///
            "}" ///
            "\end{table}")

    *-------------------------------------------*
    * Export Results: Main Table
    *-------------------------------------------*

    local outfile "$path_ol_gen/tables/ES1_`out'_full.tex"

    esttab Model1 Model2 Model3 Model4 Model5 using "`outfile'", ///
        replace ///
        b(%9.3f) se(%9.3f) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        stats(FemFem FemFemP stu_control peer_control classroom_fe r2 N, ///
              labels("Fem Peer: Fem vs Male Stu ($\beta_1 + \beta_3$)" "Fem Peer: P-val" "Student Background Controls" "Peer Background Controls" "Classroom FE" "R-squared" "Observations") ///
              fmt(%9.3f %9.3f %9.0f %9.0f %9.0f %9.3f %9.0f)) ///
        substitute("\_" "_") ///
        keep(tch_`out' obs_tch_`out' obs_self_`out' self_`out' 1.stu_fem 1.obs_fem 1.stu_fem#1.obs_fem) ///
        alignment(D{.}{.}{-1}) ///
        nogap compress label ///
        coeflabels( ///
            "1.stu_fem" "Female Student ($\beta_1$)" ///
            "1.obs_fem" "Female Peer ($\beta_2$)" ///
            "1.stu_fem#1.obs_fem" "Female Student x Female Peer ($\beta_3$)") ///
        nomtitles booktabs ///
        order(1.stu_fem 1.obs_fem 1.stu_fem#1.obs_fem obs_self_`out' tch_`out' self_`out' obs_tch_`out') ///
        prehead("\begin{table}[h!]" ///
            "\centering" ///
            "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" ///
            "\caption{\label{tab:ES1_`out'_full}Peer-Assigned Score - `lvar'}" ///
            "\resizebox{0.9\textwidth}{!}{" ///
            "\begin{tabular}{l*{5}{D{.}{.}{-1}}}" ///
            "\toprule") ///
        postfoot("\bottomrule" ///
            "\multicolumn{5}{l}{\footnotesize Standard errors in parentheses and clustered at student level. \sym{*} (p<0.10), \sym{**} (p<0.05), \sym{***} (p<0.01).}\\" ///
            "\end{tabular}" ///
            "}" ///
            "\end{table}")
}


*------------------------------------------------------------------------------*
* 3.2 Compact peer regressions: all 5 domains in one table
*------------------------------------------------------------------------------*

use "$cleanpb/class/pb_4s_all_new.dta", clear
do "${gg_shared}/analysis_dataprep.do"

* Keep only Peer evaluations
keep if pb_type == "CO"

* Initialize coefficient rows
local row_stufem       "Female Student ($\beta_1$)"
local row_stufem_se    ""
local row_peerfem      "Female Peer ($\beta_2$)"
local row_peerfem_se   ""
local row_inter        "Female Student x Female Peer ($\beta_3$)"
local row_inter_se     ""
local row_tch          "Student's Teacher Score"
local row_tch_se       ""
local row_stuself      "Student's Self Score"
local row_stuself_se   ""
local row_obstch       "Peer's Teacher Score"
local row_obstch_se    ""
local row_obsself      "Peer's Self Score"
local row_obsself_se   ""

local row_FemFem       "$\beta_1 + \beta_3$"
local row_N            "Observations"
local row_r2           "Adj. R-squared"

foreach out in $PB_out {

    areg s_std_`out' $gendervar tch_`out' obs_tch_`out' obs_self_`out' self_`out' ///
        $controls_spain_s $controls_univ_cat_s ///
        $controls_spain_p $controls_univ_cat_p, absorb(class_fixed) vce(cluster studid)

    matrix b = r(table)

    local stu_fem_coef : display %05.3f b[1, 2]
    local stu_fem_se   : display %05.3f b[2, 2]
    local stu_fem_pval : display %05.3f b[4, 2]

    local peerfem_coef : display %05.3f b[1, 4]
    local peerfem_se   : display %05.3f b[2, 4]
    local peerfem_pval : display %05.3f b[4, 4]

    local inter_coef : display %05.3f b[1, 8]
    local inter_se   : display %05.3f b[2, 8]
    local inter_pval : display %05.3f b[4, 8]

    local tch_coef : display %05.3f b[1, 9]
    local tch_se   : display %05.3f b[2, 9]
    local tch_pval : display %05.3f b[4, 9]

    local obstch_coef : display %05.3f b[1, 10]
    local obstch_se   : display %05.3f b[2, 10]
    local obstch_pval : display %05.3f b[4, 10]

    local obsself_coef : display %05.3f b[1, 11]
    local obsself_se   : display %05.3f b[2, 11]
    local obsself_pval : display %05.3f b[4, 11]

    local stuself_coef : display %05.3f b[1, 12]
    local stuself_se   : display %05.3f b[2, 12]
    local stuself_pval : display %05.3f b[4, 12]

    local N = e(N)
    local r2 : display %05.3f e(r2_a)

    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    local FemFem_coef : display %05.3f r(estimate)
    local FemFem_pval : display %05.3f r(p)

    * Add significance stars
    local plist "stu_fem peerfem inter tch obstch obsself stuself FemFem"
    foreach w in `plist' {
        local `w'_star ""
        if ``w'_pval' <= 0.01 {
            local `w'_star "***"
        }
        else if ``w'_pval' <= 0.05 {
            local `w'_star "**"
        }
        else if ``w'_pval' <= 0.1 {
            local `w'_star "*"
        }
    }

    * Build row strings
    local row_stufem     "`row_stufem' & `stu_fem_coef'`stu_fem_star'"
    local row_stufem_se  "`row_stufem_se' & (`stu_fem_se')"

    local row_peerfem    "`row_peerfem' & `peerfem_coef'`peerfem_star'"
    local row_peerfem_se "`row_peerfem_se' & (`peerfem_se')"

    local row_inter      "`row_inter' & `inter_coef'`inter_star'"
    local row_inter_se   "`row_inter_se' & (`inter_se')"

    local row_obsself    "`row_obsself' & `obsself_coef'`obsself_star'"
    local row_obsself_se "`row_obsself_se' & (`obsself_se')"

    local row_tch        "`row_tch' & `tch_coef'`tch_star'"
    local row_tch_se     "`row_tch_se' & (`tch_se')"

    local row_stuself    "`row_stuself' & `stuself_coef'`stuself_star'"
    local row_stuself_se "`row_stuself_se' & (`stuself_se')"

    local row_obstch     "`row_obstch' & `obstch_coef'`obstch_star'"
    local row_obstch_se  "`row_obstch_se' & (`obstch_se')"

    local row_FemFem     "`row_FemFem' & `FemFem_coef'`FemFem_star'"
    local row_N          "`row_N' & `N'"
    local row_r2         "`row_r2' & `r2'"
}

* Write compact table
local texfile "$path_ol_gen/tables/peer_compact.tex"

cap file close fh
file open fh using "`texfile'", write replace

file write fh _n "\begin{table}[htp]"
file write fh _n "\centering"
file write fh _n "\resizebox{0.95\textwidth}{!}{"
file write fh _n "\begin{threeparttable}"
file write fh _n "\caption{Peer-Assigned Scores: All 5 dimensions}"
file write fh _n "\label{tab:peer_compact}"
file write fh _n "\begin{tabular}{lccccc}"
file write fh _n "\toprule"
file write fh _n " & Autonomy & Cooperation  & Responsibility & Emotion & Thinking \\"
file write fh _n "\midrule"

foreach v in stufem peerfem inter obsself tch stuself obstch {
    file write fh _n "`row_`v'' \\"
    file write fh _n "`row_`v'_se' \\"
}

file write fh _n "\midrule"
file write fh _n "`row_FemFem' \\"
file write fh _n "`row_N' \\"
file write fh _n "`row_r2' \\"
file write fh _n "\bottomrule"
file write fh _n "\end{tabular}"
file write fh _n "\begin{tablenotes}[flushleft]"
file write fh _n "\footnotesize"
file write fh _n "\item Note: All regressions control for student and peer background characteristics, and classroom fixed effects. Standard errors clustered at student level in parentheses. The dependent variable is peer-assigned score. *p<0.10, ** p<0.05, *** p<0.01."
file write fh _n "\end{tablenotes}"
file write fh _n "\end{threeparttable}"
file write fh _n "}"
file write fh _n "\end{table}"

file close fh


*------------------------------------------------------------------------------*
* 3.3 Peer FE vs Student FE comparison: all 5 domains
*------------------------------------------------------------------------------*

use "$cleanpb/class/pb_4s_all_new.dta", clear
do "${gg_shared}/analysis_dataprep.do"

keep if pb_type == "CO"

* Initialize coefficient and SE row macros
local femfem_coef_row ""
local femfem_se_row   ""
local malemale_coef_row ""
local malemale_se_row   ""
local tch_coef_row ""
local tch_se_row   ""
local self_coef_row ""
local self_se_row   ""

* Initialize Observations and R-squared rows
local N_row ""
local r2_row ""

foreach out in $PB_out {

    *===================== STUDENT FE: Female x Female =====================*
    areg s_std_`out' i.stu_fem##i.obs_fem obs_tch_`out' obs_self_`out' ///
        $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(stu_fixed)

    lincom (_b[1.obs_fem] + _b[1.stu_fem#1.obs_fem])
    scalar FFsfe_b = r(estimate)
    local FFsfe_b = string(FFsfe_b, "%5.3f")
    scalar FFsfe_se = r(se)
    local FFsfe_se = string(FFsfe_se, "%5.3f")
    scalar FFsfe_p = r(p)
    local FFsfe_p = string(FFsfe_p, "%9.3f")

    local Nsfe : display %4.0f e(N)
    local r2sfe : display %5.3f e(r2)

    *===================== STUDENT FE: Male x Male =====================*
    areg s_std_`out' i.stu_male##i.obs_male obs_tch_`out' obs_self_`out' ///
        $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(stu_fixed)

    lincom (_b[1.obs_male] + _b[1.stu_male#1.obs_male])
    scalar MMsfe_b = r(estimate)
    local MMsfe_b = string(MMsfe_b, "%5.3f")
    scalar MMsfe_se = r(se)
    local MMsfe_se = string(MMsfe_se, "%5.3f")
    scalar MMsfe_p = r(p)
    local MMsfe_p = string(MMsfe_p, "%9.3f")

    *===================== PEER FE: Female x Female =====================*
    areg s_std_`out' i.stu_fem##i.obs_fem tch_`out' self_`out' ///
        $controls_spain_s $controls_univ_cat_s, vce(cluster studid) absorb(obs_fixed)

    lincom (_b[1.stu_fem] + _b[1.stu_fem#1.obs_fem])
    scalar FFpfe_b = r(estimate)
    local FFpfe_b = string(FFpfe_b, "%5.3f")
    scalar FFpfe_se = r(se)
    local FFpfe_se = string(FFpfe_se, "%5.3f")
    scalar FFpfe_p = r(p)
    local FFpfe_p = string(FFpfe_p, "%9.3f")

    local Npfe : display %4.0f e(N)
    local r2pfe : display %5.3f e(r2)

    *===================== PEER FE: Male x Male =====================*
    areg s_std_`out' i.stu_male##i.obs_male tch_`out' self_`out' ///
        $controls_spain_s $controls_univ_cat_s, vce(cluster studid) absorb(obs_fixed)

    lincom (_b[1.stu_male] + _b[1.stu_male#1.obs_male])
    scalar MMpfe_b = r(estimate)
    local MMpfe_b = string(MMpfe_b, "%5.3f")
    scalar MMpfe_se = r(se)
    local MMpfe_se = string(MMpfe_se, "%5.3f")
    scalar MMpfe_p = r(p)
    local MMpfe_p = string(MMpfe_p, "%9.3f")

    *===================== TEACHER & SELF (SFE & PFE) =====================*
    * Student FE
    areg s_std_`out' i.stu_fem##i.obs_fem obs_tch_`out' obs_self_`out' ///
        $controls_spain_p $controls_univ_cat_p, vce(cluster studid) absorb(stu_fixed)
    matrix b_sfe = r(table)
    local col_tch_sfe = colnumb(b_sfe, "obs_tch_`out'")
    local tch_sfe_b  : display %5.3f b_sfe[1, `col_tch_sfe']
    local tch_sfe_se : display %5.3f b_sfe[2, `col_tch_sfe']
    local tch_sfe_p  : display %9.3f b_sfe[4, `col_tch_sfe']

    local col_self_sfe = colnumb(b_sfe, "obs_self_`out'")
    local self_sfe_b  : display %5.3f b_sfe[1, `col_self_sfe']
    local self_sfe_se : display %5.3f b_sfe[2, `col_self_sfe']
    local self_sfe_p  : display %9.3f b_sfe[4, `col_self_sfe']

    * Peer FE
    areg s_std_`out' i.stu_fem##i.obs_fem tch_`out' self_`out' ///
        $controls_spain_s $controls_univ_cat_s, vce(cluster studid) absorb(obs_fixed)
    matrix b_pfe = r(table)
    local col_tch_pfe = colnumb(b_pfe, "tch_`out'")
    local tch_pfe_b  : display %5.3f b_pfe[1, `col_tch_pfe']
    local tch_pfe_se : display %5.3f b_pfe[2, `col_tch_pfe']
    local tch_pfe_p  : display %9.3f b_pfe[4, `col_tch_pfe']

    local col_self_pfe = colnumb(b_pfe, "self_`out'")
    local self_pfe_b  : display %5.3f b_pfe[1, `col_self_pfe']
    local self_pfe_se : display %5.3f b_pfe[2, `col_self_pfe']
    local self_pfe_p  : display %9.3f b_pfe[4, `col_self_pfe']

    *===================== Add Significance Stars =====================*
    local plist "FFsfe MMsfe tch_sfe self_sfe FFpfe MMpfe tch_pfe self_pfe"
    foreach w in `plist' {
        local `w'_star ""
        if ``w'_p' <= 0.01 {
            local `w'_star "***"
        }
        else if ``w'_p' <= 0.05 {
            local `w'_star "**"
        }
        else if ``w'_p' <= 0.1 {
            local `w'_star "*"
        }
    }

    * Build final output strings
    local FFpfe_out "`FFpfe_b'`FFpfe_star'"
    local FFsfe_out "`FFsfe_b'`FFsfe_star'"
    local MMpfe_out "`MMpfe_b'`MMpfe_star'"
    local MMsfe_out "`MMsfe_b'`MMsfe_star'"
    local tch_pfe_out "`tch_pfe_b'`tch_pfe_star'"
    local tch_sfe_out "`tch_sfe_b'`tch_sfe_star'"
    local self_pfe_out "`self_pfe_b'`self_pfe_star'"
    local self_sfe_out "`self_sfe_b'`self_sfe_star'"

    * FemFem row: (Peer FE, Student FE)
    local femfem_coef_row "`femfem_coef_row' & `FFpfe_out' & `FFsfe_out'"
    local femfem_se_row   "`femfem_se_row' & (`FFpfe_se') & (`FFsfe_se')"

    * MaleMale row: (Peer FE, Student FE)
    local malemale_coef_row "`malemale_coef_row' & `MMpfe_out' & `MMsfe_out'"
    local malemale_se_row   "`malemale_se_row' & (`MMpfe_se') & (`MMsfe_se')"

    * Self row: (Peer FE, Student FE)
    local self_coef_row "`self_coef_row' & `self_pfe_out' & `self_sfe_out'"
    local self_se_row   "`self_se_row' & (`self_pfe_se') & (`self_sfe_se')"

    * Teacher row: (Peer FE, Student FE)
    local tch_coef_row "`tch_coef_row' & `tch_pfe_out' & `tch_sfe_out'"
    local tch_se_row   "`tch_se_row' & (`tch_pfe_se') & (`tch_sfe_se')"

    * Observations and R-squared: 2 columns per domain (PeerFE, StudentFE)
    local N_row "`N_row' & `Npfe' & `Nsfe'"
    local r2_row "`r2_row' & `r2pfe' & `r2sfe'"
}

* Write comparison table
cap file close fh
file open fh using "$path_ol_gen/tables/FE_5domains.tex", write replace

file write fh _n "\begin{landscape}"
file write fh _n "\begin{table}[htp]\centering"
file write fh _n "\resizebox{0.98\paperwidth}{!}{"
file write fh _n "\begin{threeparttable}"
file write fh _n "\caption{Peer-Assigned Score: Peer FE vs. Student FE Across 5 Domains}"
file write fh _n "\label{tab:FE_all}"
file write fh _n "\begin{tabular}{lcccccccccc}"
file write fh _n "\toprule"

file write fh _n " & \multicolumn{2}{c}{\textbf{Autonomy}} & \multicolumn{2}{c}{\textbf{Cooperation}} & \multicolumn{2}{c}{\textbf{Responsibility}} & \multicolumn{2}{c}{\textbf{Emotion Mngt.}} & \multicolumn{2}{c}{\textbf{Thinking Ab.}} \\"
file write fh _n " & \textbf{Peer FE} & \textbf{Student FE} & \textbf{Peer FE} & \textbf{Student FE} & \textbf{Peer FE} & \textbf{Student FE} & \textbf{Peer FE} & \textbf{Student FE} & \textbf{Peer FE} & \textbf{Student FE} \\"

file write fh _n "\midrule"

file write fh _n "Fem Student x Fem Peer `femfem_coef_row'\\"
file write fh _n "  `femfem_se_row'\\"
file write fh _n "Male Student x Male Peer `malemale_coef_row'\\"
file write fh _n "  `malemale_se_row'\\"
file write fh _n "Self Score `self_coef_row'\\"
file write fh _n "  `self_se_row'\\"
file write fh _n "Teacher Score `tch_coef_row'\\"
file write fh _n "  `tch_se_row'\\"
file write fh _n "\midrule"
file write fh _n "Peer Controls & No & Yes & No & Yes & No & Yes & No & Yes & No & Yes \\"
file write fh _n "Student Controls & Yes & No & Yes & No & Yes & No & Yes & No & Yes & No \\"
file write fh _n "Observations`N_row'\\"
file write fh _n "R-squared`r2_row'\\"
file write fh _n "\bottomrule"
file write fh _n "\end{tabular}"

file write fh _n "\begin{tablenotes}[flushleft]"
file write fh _n "\footnotesize"
file write fh _n "\item Note: Standard errors in parentheses and clustered at the student level. The dependent variable is peer-assigned score. Under Peer FEs, the Teacher and Self Score refers to student's scores and under Student FEs, these refer to the peer's scores . *p<0.10, ** p<0.05, *** p<0.010."
file write fh _n "\end{tablenotes}"
file write fh _n "\end{threeparttable}"
file write fh _n "}"
file write fh _n "\end{table}"
file write fh _n "\end{landscape}"

file close fh


********************************************************************************
*                           END OF ACTIVE CODE                                 *
*   The following sections contain archived/deprecated regression code.        *
*   These are retained for reference but are not executed.                     *
********************************************************************************

/*
================================================================================
ARCHIVED CODE: Older regression specifications
================================================================================

The code below contains earlier versions of regression specifications that have
been superseded by the main analysis above. They are preserved here for:
1. Reference to earlier estimation strategies
2. Reproducibility of prior results
3. Documentation of analytical evolution

These sections include:
- Estimation Strategy 4: Peer score deviation analysis
- Estimation Strategy 3: Student FE and Peer FE specifications (females/males)
- Estimation Strategy 2: Classroom FE with interaction terms
- Estimation Strategy 1: Various clustering and FE combinations
- 7-model specifications with EO variables
- School FE and complexity FE specifications

To execute any of these sections, remove the block comment markers.
================================================================================
*/

* END OF FILE
