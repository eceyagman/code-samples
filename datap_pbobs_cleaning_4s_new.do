********************************************************************************
*                    ALL PB EVALUATIONS - 4 SOURCES                            *
********************************************************************************
/*
* Creator:        Ece Yagman
* Creation date:  21/01/2025
* Last modified:  17/02/2026
* Purpose:        Clean all PB observations from 4 sources (PEER, SELF, TEACHER,
*                 RESEARCH/EO) and prepare dataset for gender gap analysis
*
* DEPENDENCIES:
*   - Requires globals defined: $intpbobs, $cleanids, $cleanlogistics, $Rclean,
*     $intgender, $cleangender, $cleanpb
*   - Requires ado files: PBMeasure_peer, PBMeasure_self, PBMeasure_tch_class,
*     PBMeasure_eo
*
* INPUTS:
*   - $intpbobs/datap_pbobs_harmonised.dta    : Harmonized PB observations
*   - $cleanids/cat_master_students.dta       : Student master file
*   - $cleanlogistics/calendar_datasource_group_lvl_wide.dta : Observation dates
*   - $Rclean/std_survey_final.dta            : Student survey data
*   - $Rclean/teacher_surveys/tch_surveys.dta : Teacher survey data
*   - $Rclean/analysis_students.dta           : Student analysis file
*   - $intpbobs/pbvars_con.dta                : PB variable labels
*
* OUTPUTS:
*   - $intpbobs/datap_pbobs_4s_T2.dta         : Term 2 collapsed data
*   - $intpbobs/datap_pbobs_4s_T3.dta         : Term 3 collapsed data
*   - $intgender/tch_endline.dta              : Teacher endline data
*   - $cleanpb/class/pb_4s_all_new.dta        : Final cleaned dataset (MAIN OUTPUT)
*
* STRUCTURE:
*   1. Load and initial cleaning
*   2. Process RESEARCH observations (wave assignment, outlier handling)
*   3. Split by academic terms
*   4. Merge student/observer/teacher characteristics
*   5. Generate standardized PB scores
*   6. Create gender variables and pairings
*   7. Generate aggregated scores (teacher, self, peer, EO)
*   8. Calculate deviation scores
*   9. Final sample restrictions and save
*/
********************************************************************************

version 17
clear all
set more off

********************************************************************************
*                         PROGRAM DEFINITIONS                                  *
********************************************************************************

* Program: Generate male/female binary variables from gender variable
* Usage: gen_gender_binaries prefix, gendervar(varname) malelbl(string) femlbl(string)
capture program drop gen_gender_binaries
program define gen_gender_binaries
    syntax namelist(max=1), gendervar(varname) malelbl(string) femlbl(string)

    local prefix `namelist'

    * Generate male indicator
    gen `prefix'_male = (`gendervar' == 1)
    replace `prefix'_male = . if `gendervar' == . | `gendervar' == 3 | `gendervar' == .m
    label var `prefix'_male "`malelbl'"

    * Generate female indicator (inverse of male)
    gen `prefix'_fem = .
    replace `prefix'_fem = 1 if `prefix'_male == 0
    replace `prefix'_fem = 0 if `prefix'_male == 1
    label var `prefix'_fem "`femlbl'"
end

* Program: Generate scores by gender subgroups
* Usage: gen_scores_by_gender prefix, scorevar(stub) gendervar(varname) byvar(varlist)
capture program drop gen_scores_by_gender
program define gen_scores_by_gender
    syntax namelist(max=1), scorevar(string) gendervar(varname) byvar(varlist) femlbl(string) malelbl(string)

    local prefix `namelist'
    local dimensions autonomy cooperation emotion responsibility thinking

    foreach d of local dimensions {
        * Female subgroup score
        bys `byvar': egen `prefix'F_`d' = mean(cond(`gendervar' == 1, `scorevar'_`d', .))
        label var `prefix'F_`d' "`femlbl': `d'"

        * Male subgroup score
        bys `byvar': egen `prefix'M_`d' = mean(cond(`gendervar' == 0, `scorevar'_`d', .))
        label var `prefix'M_`d' "`malelbl': `d'"
    }
end

* Program: Label domain variables with a prefix
* Usage: label_domains prefix, lbl(string)
capture program drop label_domains
program define label_domains
    syntax namelist(max=1), lbl(string)

    local prefix `namelist'
    local dimensions autonomy cooperation emotion responsibility thinking

    foreach d of local dimensions {
        capture label var `prefix'_`d' "`lbl': `d'"
    }
end

********************************************************************************
*                      1. LOAD DATA AND INITIAL CLEANING                       *
********************************************************************************

use "$intpbobs/datap_pbobs_harmonised", clear

* Validate input data
qui count
local initial_obs = r(N)
assert `initial_obs' > 0
di as text "Loaded `initial_obs' observations from harmonised PB data"

* Drop PB dimension evaluations, we only use subdomain evaluations
drop if pb_subdim == "_root"

* Date variable
gen date_s = date(pb_date, "YMD")
format date_s %td

* Group variable cleanup
rename group grup
gen group = substr(grup, -2, .)

********************************************************************************
*                    2. PROCESS RESEARCH OBSERVATIONS                          *
********************************************************************************

* Clean research observations only
preserve
    keep if pb_type == "RESEARCH"

    **************************************************************************
    *                  MERGE WITH MASTER_ID: GRADECLASS                      *
    **************************************************************************
    merge m:1 studid using "$cleanids/cat_master_students", ///
        keepusing(gradeclass) keep(matched) nogen

    **************************************************************************
    *                    MERGE LOGISTICS INFO                                *
    **************************************************************************
    merge m:1 schlid gradeclass using "$cleanlogistics/calendar_datasource_group_lvl_wide", ///
        keepusing(Observations_LabField Observations_Wave_1 Observations_Wave_2 ///
                  Observations_Wave_3 Observations_Wave_4 Observations_Wave_5) nogen

    * Assign wave based on observation date
    gen wave = "1" if date_s == Observations_Wave_1 & pb_type == "RESEARCH"
    replace wave = "2" if date_s == Observations_Wave_2 & pb_type == "RESEARCH"
    replace wave = "3" if date_s == Observations_Wave_3 & pb_type == "RESEARCH"
    replace wave = "4" if date_s == Observations_Wave_4 & pb_type == "RESEARCH"
    replace wave = "5" if date_s == Observations_Wave_5 & pb_type == "RESEARCH"
    replace wave = "FA" if date_s == Observations_LabField & pb_type == "RESEARCH"

    sort date_s schlid gradeclass studid
    drop Observations_*

    **************************************************************************
    *              MANUAL CORRECTIONS FOR MISMATCHED LOGISTICS               *
    **************************************************************************
    * Note: These corrections are based on "fitxas d'aula" field notes

    * School 8030947, Class 2B, 2022-11-24: Class list problems, repeated 28 Nov
    replace wave = "Incorrect observation" if schlid == "8030947" & ///
        gradeclass == "2B" & pb_date == "2022-11-24"

    * School 8013093: Outlier students requiring further revision
    replace wave = "Outlier students: further revision needed" if ///
        schlid == "8013093" & gradeclass == "3B" & ///
        studid == "9b53d4d61235bd05844d586bd95f8cd35b5f15b9287f04e1156f0035f0abf8d8" & ///
        pb_date == "2022-11-30"

    replace wave = "Outlier students: further revision needed" if ///
        schlid == "8013093" & gradeclass == "1A" & ///
        (studid == "540549cd2f1ee4076802ad545a5d816d0ceda58ba912af2dfff332367861cdee" | ///
         studid == "89f043a5fba389d63e4c52489a8b520d248e823d7512479e6958dde5beaed16b" | ///
         studid == "936e18dc37c2028193b98d0a3c176761de297e3d8fb1adae7f91f918c1054ddc") & ///
        pb_date == "2023-2-15"

    replace wave = "Outlier students: further revision needed" if ///
        schlid == "8013093" & gradeclass == "3B" & ///
        studid == "9b53d4d61235bd05844d586bd95f8cd35b5f15b9287f04e1156f0035f0abf8d8" & ///
        pb_date == "2023-2-22"

    * School 8046748, Class 2B: Teacher absence, rescheduled observations
    replace wave = "4" if schlid == "8046748" & gradeclass == "2B" & pb_date == "2023-4-17"
    replace wave = "5" if schlid == "8046748" & gradeclass == "2B" & pb_date == "2023-4-24"

    * School 8077083, Class 2B, 2023-4-17: Class dynamics issues, repeated May 4th
    replace wave = "Incorrect observation" if schlid == "8077083" & ///
        gradeclass == "2B" & pb_date == "2023-4-17"

    * School 8059688, Class 1D, 2023-4-25: New observers only, repeated May 10th
    replace wave = "Incorrect observation" if schlid == "8059688" & ///
        gradeclass == "1D" & pb_date == "2023-4-25"

    **************************************************************************
    *                       SAMPLE RESTRICTION                               *
    **************************************************************************

    * Count exclusions for validation
    qui count if wave == "Incorrect observation"
    local n_incorrect = r(N)
    qui count if wave == "Outlier students: further revision needed"
    local n_outlier = r(N)
    qui count if wave == "FA"
    local n_fa = r(N)

    di as text "RESEARCH exclusions: Incorrect=`n_incorrect', Outliers=`n_outlier', FA=`n_fa'"

    drop if wave == "Incorrect observation"
    drop if wave == "Outlier students: further revision needed"
    drop if wave == "FA"  // Only keep in-class observations, drop lab-in-the-field

    tempfile research
    save `research'
restore

drop if pb_type == "RESEARCH"
append using `research'

********************************************************************************
*                    3. COLLAPSE AND SPLIT BY ACADEMIC TERMS                   *
********************************************************************************

* Term boundaries (2022-2023 school year)
* Term 1: Before 09 Jan 2023
* Term 2: 09 Jan 2023 to 10 Apr 2023
* Term 3: 11 Apr 2023 onwards

gen term = ""
replace term = "1" if date_s < date("09jan2023", "DMY")
replace term = "2" if date_s >= date("09jan2023", "DMY") & date_s < date("11apr2023", "DMY")
replace term = "3" if date_s >= date("11apr2023", "DMY")

* Validation: Check term assignment
qui tab term, m
di as text "Term distribution:"
tab term

* Save Term 2 data
preserve
    keep if term == "2"
    qui count
    di as text "Term 2 observations: `r(N)'"
    collapse (mean) pb_val, by(schlid group gradeclass studid obsid eosid pb_type pb_dim pb_subdim)
    save "$intpbobs/datap_pbobs_4s_T2", replace
restore

* Save Term 3 data
preserve
    keep if term == "3"
    qui count
    di as text "Term 3 observations: `r(N)'"
    collapse (mean) pb_val, by(schlid group gradeclass studid obsid eosid pb_type pb_dim pb_subdim)
    save "$intpbobs/datap_pbobs_4s_T3", replace
restore

* All Terms: Remove time dimension, keep mean subdomain score by observer
collapse (mean) pb_val, by(schlid group studid obsid eosid pb_type pb_dim pb_subdim)

********************************************************************************
*                4. MERGE WITH MASTER ID AND FILTER SAMPLE                     *
********************************************************************************

merge m:1 studid using "$cleanids/cat_master_students", ///
    keepusing(gradeclass municipality treat_group survey_status attrition consent complexity) ///
    keep(matched) nogen

* Validate consent
assert consent == "Consented"
drop consent

* Sample restrictions
qui count if treat_group == 0
local n_control = r(N)
drop if treat_group == 0
di as text "Dropped `n_control' control group observations"

qui count if survey_status == "Not surveyed"
local n_not_surveyed = r(N)
drop if survey_status == "Not surveyed"
di as text "Dropped `n_not_surveyed' not surveyed observations"

drop survey_status group

* Create grade and class variables
gen grade = substr(gradeclass, 1, 1)
gen class = substr(gradeclass, 2, .)
label var grade "Grade of the student"
label var class "Class of the student"

********************************************************************************
*                 5. GENERATE STANDARDIZED PB SCORES                           *
********************************************************************************

* Peer and CO scores
PBMeasure_peer pb_val, id(studid) obsid(obsid) pbdim(pb_dim) pbsubdom(pb_subdim) pbtype(pb_type)

* Self scores
PBMeasure_self pb_val, id(studid) obsid(obsid) pbdim(pb_dim) pbsubdom(pb_subdim) pbtype(pb_type)

* Harmonize peer/co and self scores
local s_vars s_subdom s_std_subdom s_dom s_std_dom
local self_vars self_subdom self_std_subdom self_dom self_std_dom

local i = 1
foreach var of local s_vars {
    local self_var : word `i' of `self_vars'
    replace `var' = `self_var' if missing(`var') & pb_type == "SELF"
    local i = `i' + 1
}
drop `self_vars'

* Teacher scores
PBMeasure_tch_class pb_val, id(studid) obsid(obsid) pbdim(pb_dim) pbsubdom(pb_subdim) pbtype(pb_type)

* Harmonize teacher scores
local tch_vars tch_subdom tch_std_subdom tch_dom tch_std_dom

local i = 1
foreach var of local s_vars {
    local tch_var : word `i' of `tch_vars'
    replace `var' = `tch_var' if missing(`var') & pb_type == "TEACHER"
    local i = `i' + 1
}
drop `tch_vars'

********************************************************************************
*                        6. ADD EO GENDER                                      *
********************************************************************************

replace eosid = trim(regexr(eosid, "\. *$", ""))

* NOTE: real observer names have been replaced with anonymized IDs (EO_001..EO_018)
* for public release of this code sample. The gender coding logic is unchanged.

* Remove RA who was incorrectly logged as an external observer
drop if eosid == "EO_RA_001"

* EO gender coding
* Female EOs
gen eo_fem = .
replace eo_fem = 1 if inlist(eosid, "EO_001", "EO_002", ///
    "EO_003", "EO_004", "EO_005", ///
    "EO_006", "EO_007")
replace eo_fem = 1 if inlist(eosid, "EO_008", "EO_009", ///
    "EO_010", "EO_011", "EO_012", "EO_013", ///
    "EO_014")

* Male EOs
replace eo_fem = 0 if inlist(eosid, "EO_015", "EO_016", ///
    "EO_017")

label var eo_fem "Female EO"

* Validation: Check for unassigned EO genders
qui count if eo_fem == . & pb_type == "RESEARCH"
if r(N) > 0 {
    di as error "WARNING: `r(N)' RESEARCH observations with missing EO gender"
    tab eosid if eo_fem == . & pb_type == "RESEARCH"
}

* EO (Research) scores
PBMeasure_eo pb_val, id(studid) obsid(obsid) pbdim(pb_dim) pbsubdom(pb_subdim) pbtype(pb_type)

* Harmonize EO scores
local eo_vars eo_subdom eo_std_subdom eo_dom eo_std_dom

local i = 1
foreach var of local s_vars {
    local eo_var : word `i' of `eo_vars'
    replace `var' = `eo_var' if missing(`var') & pb_type == "RESEARCH"
    local i = `i' + 1
}
drop `eo_vars'

********************************************************************************
*                    7. ADD SOCIOECONOMIC INDEX                                *
********************************************************************************

preserve
    use "$Rclean/std_survey_final", clear

    * Recode amenity variables (1 = possessed, 2 = not possessed -> 0/1)
    label define hasamenity 0 "No" 1 "Yes"
    foreach x in qst_hh_hasheater_bl qst_hh_hasinternet_bl qst_hh_hascomputer_bl qst_hh_hastablet_bl {
        replace `x' = (`x' == 1) if `x' != . & `x' != .n & `x' != .m
        label val `x' hasamenity
    }

    * Recode bedrooms (98 -> 4, per original codebook)
    replace qst_hh_numbedroom_bl = 4 if qst_hh_numbedroom_bl == 98

    * Generate socio-economic index (sum of bedrooms + 4 amenity indicators)
    gen qst_hh_socioecon_index_bl = qst_hh_numbedroom_bl
    foreach x in qst_hh_hasheater_bl qst_hh_hasinternet_bl qst_hh_hascomputer_bl qst_hh_hastablet_bl {
        replace qst_hh_socioecon_index_bl = qst_hh_socioecon_index_bl + `x'
    }
    label var qst_hh_socioecon_index_bl "Household socio-economic index"

    * Binarized SES for heterogeneity analysis
    qui sum qst_hh_socioecon_index_bl, d
    local median = r(p50)
    gen hh_lowses_index = (qst_hh_socioecon_index_bl < `median')
    replace hh_lowses_index = . if missing(qst_hh_socioecon_index_bl)
    label var hh_lowses_index "Low socio-economic background household"

    * Any caregiver born in Spain (12 = Spain)
    gen qst_careg_born_spain_dum = (qst_caregiver1_born_spain_el == 12 | qst_caregiver2_born_spain_el == 12)
    replace qst_careg_born_spain_dum = . if missing(qst_caregiver1_born_spain_el) & missing(qst_caregiver2_born_spain_el)
    label var qst_careg_born_spain_dum "Any caregiver born in Spain"

    tempfile std_survey_hh
    save `std_survey_hh'
restore

********************************************************************************
*             8. MERGE STUDENT SURVEY DATA (GENDER, PLACE OF BIRTH)            *
********************************************************************************

local stu_data schlid gradeid classid studid treat_grade qst_gender qst_datebirth_el ///
    qst_age_years_el qst_born_spain qst_born_country qst_caregiver1_el qst_caregiver2_el ///
    qst_caregiver1_born_spain_el qst_caregiver1_born_country_el qst_caregiver1_born_continent_el ///
    qst_caregiver2_born_spain_el qst_caregiver2_born_country_el qst_caregiver2_born_continent_el ///
    qst_caregiver1_univ_el qst_caregiver1_studies_el qst_caregiver2_univ_el qst_caregiver2_studies_el ///
    qst_hh_socioecon_index_bl hh_lowses_index qst_careg_born_spain_dum ///
    qst_eyestest_score_bl qst_eyestest_score_el

* Rename IDs for merge
rename studid studcode
rename schlid schlcode
rename obsid obscode

merge m:1 studcode using `std_survey_hh', keepusing(`stu_data') gen(m_endline)
drop if m_endline == 2

* Validation
qui count if m_endline == 1
di as text "Student survey merge: `r(N)' unmatched from master"

* Rename variables from qst_ to stu_ prefix
foreach var in `stu_data' {
    local newname = subinstr("`var'", "qst", "stu", .)
    rename `var' `newname'
}
rename hh_lowses_index stu_lowses_index

********************************************************************************
*          9. MERGE OBSERVER (PEER) SURVEY DATA                                *
********************************************************************************

preserve
    use `std_survey_hh', clear
    rename studcode obscode
    rename studid obsid
    tempfile obs_endline
    save `obs_endline'
restore

local obs_data obsid qst_gender qst_datebirth_el qst_age_years_el qst_born_spain qst_born_country ///
    qst_caregiver1_el qst_caregiver2_el qst_caregiver1_born_spain_el qst_caregiver1_born_country_el ///
    qst_caregiver1_born_continent_el qst_caregiver2_born_spain_el qst_caregiver2_born_country_el ///
    qst_caregiver2_born_continent_el qst_caregiver1_univ_el qst_caregiver1_studies_el ///
    qst_caregiver2_univ_el qst_caregiver2_studies_el qst_hh_socioecon_index_bl hh_lowses_index ///
    qst_careg_born_spain_dum qst_eyestest_score_bl qst_eyestest_score_el

merge m:1 obscode using `obs_endline', keepusing(`obs_data') gen(m_endline_o)
drop if m_endline_o == 2

* Validation
qui count if m_endline_o == 1
di as text "Observer survey merge: `r(N)' unmatched from master"

* Rename variables from qst_ to obs_ prefix
foreach var in `obs_data' {
    local newname = subinstr("`var'", "qst", "obs", .)
    rename `var' `newname'
}
rename hh_lowses_index obs_lowses_index

********************************************************************************
*                     10. MERGE TEACHER SURVEY DATA                            *
********************************************************************************

preserve
    use "$Rclean/teacher_surveys/tch_surveys.dta", clear
    sort tch_code

    * Recode teacher gender (swap 1<->2 to match student coding)
    recode qtch_gender_bl qtch_gender_el (1=2) (2=1)
    label define gender 1 "Male" 2 "Female"
    label val qtch_gender_bl gender
    label val qtch_gender_el gender

    * Keep row with fewest missing values per teacher
    egen nmissing = rowmiss(qtch_datebirth_mo_bl qtch_datebirth_day_bl qtch_datebirth_yr_bl ///
        qtch_datebirth_mo_el qtch_datebirth_day_el qtch_datebirth_yr_el qtch_gender_bl ///
        qtch_gender_el qtch_educ_level_bl qtch_educ_level_el qtch_subject_experience_bl ///
        qtch_subject_experience_el qtch_type_contract_bl qtch_type_contract_el ///
        qtch_group_hours_bl qtch_group_experience_bl qtch_group_hours_el qtch_group_experience_el)

    bysort tch_code (nmissing): keep if _n == 1

    * Final teacher gender: baseline, impute with endline if missing
    gen qtch_gender = qtch_gender_bl
    replace qtch_gender = qtch_gender_el if missing(qtch_gender)
    label val qtch_gender gender

    drop nmissing
    gen tchcode = tch_code
    rename tch_code obscode

    save "$intgender/tch_endline", replace
restore

local tch_data qtch_datebirth_mo_el qtch_datebirth_day_el qtch_datebirth_yr_el qtch_gender ///
    qtch_educ_level_bl qtch_educ_level_el qtch_subject_experience_bl qtch_subject_experience_el ///
    qtch_type_contract_el qtch_group_hours_bl qtch_group_experience_bl qtch_group_hours_el ///
    qtch_group_experience_el qtch_startdate_el

merge m:1 obscode using "$intgender/tch_endline", keepusing(`tch_data') gen(m_endline_t)
drop if m_endline_t == 2

* Validation
qui count if m_endline_t == 1
di as text "Teacher survey merge: `r(N)' unmatched from master"

* Rename variables from qtch_ to tch_ prefix
foreach var in `tch_data' {
    local newname = subinstr("`var'", "qtch", "tch", .)
    rename `var' `newname'
}

********************************************************************************
*              11. MERGE CLASS-LEVEL TEACHER DATA                              *
********************************************************************************

preserve
    local tch_data qtch_datebirth_mo_el qtch_datebirth_day_el qtch_datebirth_yr_el qtch_gender ///
        qtch_educ_level_bl qtch_educ_level_el qtch_subject_experience_bl qtch_subject_experience_el ///
        qtch_type_contract_el qtch_group_hours_bl qtch_group_experience_bl qtch_group_hours_el ///
        qtch_group_experience_el qtch_startdate_el

    use "$Rclean/analysis_students.dta", clear
    keep schlcode gradeclass classid tchcode tot_teachers_class

    bys classid: gen uni_class = _n
    keep if uni_class == 1

    merge m:1 tchcode using "$intgender/tch_endline", keepusing(`tch_data') gen(m_tchcode)
    drop if m_tchcode == 2

    tempfile tch_code
    save `tch_code'
restore

merge m:1 classid using `tch_code', keepusing(tchcode tot_teachers_class q*) keep(1 3)

* Note: 5 cases where PB observation teacher and survey teacher don't match
* (classids: 0321, 0511, 2421, 3011, 4041) - evaluations from non-primary teacher

* Order variables
order schlid schlcode gradeid classid gradeclass* studid studcode, first
order obsid, before(obscode)
order tchcode, before(tch_startdate_el)

********************************************************************************
*                    12. CREATE GENDER VARIABLES                               *
********************************************************************************

* Use program for student, observer, and teacher gender binaries
gen_gender_binaries stu, gendervar(stu_gender) malelbl("Male Student") femlbl("Female Student")
gen_gender_binaries obs, gendervar(obs_gender) malelbl("Male Peer") femlbl("Female Peer")
gen_gender_binaries tch, gendervar(tch_gender) malelbl("Male Teacher") femlbl("Female Teacher")

* Classroom teacher gender (from class-level merge)
gen qtch_male = (qtch_gender == 1)
replace qtch_male = . if qtch_gender == .
label var qtch_male "Male Teacher"

gen qtch_fem = .
replace qtch_fem = 1 if qtch_male == 0
replace qtch_fem = 0 if qtch_male == 1
label var qtch_fem "Female Teacher"

* Gender pairing variable (for CO evaluations only)
gen pairing = . if pb_type == "CO"
replace pairing = 1 if stu_male == 1 & obs_male == 1 & pb_type == "CO"  // M-M
replace pairing = 2 if stu_male == 1 & obs_male == 0 & pb_type == "CO"  // F-M
replace pairing = 3 if stu_male == 0 & obs_male == 1 & pb_type == "CO"  // M-F
replace pairing = 4 if stu_male == 0 & obs_male == 0 & pb_type == "CO"  // F-F
replace pairing = . if (stu_male == . | obs_male == .) & pb_type == "CO"

label define pairinglbl 1 "Male peer-Male stu" 2 "Fem peer-Male stu" ///
                        3 "Male peer-Fem stu" 4 "Fem peer-Fem stu"
label values pairing pairinglbl
label var pairing "Peer-Student Gender Pairing"

* Validation: Check gender pairing distribution
di as text "Gender pairing distribution (CO only):"
tab pairing if pb_type == "CO", m

********************************************************************************
*                      13. CREATE AGE VARIABLES                                *
********************************************************************************

label var stu_age_years_el "Student Age"
label var obs_age_years_el "Observer Age"

* Teacher age calculation
foreach stem in qtch tch {
    * Year of birth (coded as offset from 1949)
    gen `stem'_year_of_birth = 1949 + `stem'_datebirth_yr_el

    * Build daily date
    gen `stem'_datebirth = mdy(`stem'_datebirth_mo_el, `stem'_datebirth_day_el, `stem'_year_of_birth)
    format `stem'_datebirth %td

    * Age at survey (years)
    gen `stem'_age_days = `stem'_startdate_el - `stem'_datebirth
    gen `stem'_age = `stem'_age_days / 365.25
    label var `stem'_age "Teacher Age"

    * Clean up helper variables
    drop `stem'_age_days `stem'_year_of_birth
}

********************************************************************************
*               14. CREATE PLACE OF BIRTH AND EDUCATION VARIABLES              *
********************************************************************************

* Student and observer born in Spain
gen stu_spain = (stu_born_spain == 1)
replace stu_spain = . if stu_born_spain == .
label var stu_spain "Student born in Spain"

gen obs_spain = (obs_born_spain == 1)
replace obs_spain = . if obs_born_spain == .
label var obs_spain "Peer born in Spain"

* Caregiver education and origin variables
label define cg_edu_lbl 1 "Yes" 2 "No" 3 "Don't know", replace

foreach role in stu obs {
    if "`role'" == "stu" local who "Student"
    else                 local who "Peer"

    foreach c of numlist 1 2 {
        * Born in Spain (12 = yes, 13 = no)
        recode `role'_caregiver`c'_born_spain_el (12 = 1) (13 = 0) (else = .), ///
            gen(`role'_cg`c'_spain)
        label var `role'_cg`c'_spain "`who' Caregiver `c': Born in Spain"

        * Attended university (1 = yes, 2 = no, 6 = don't know)
        recode `role'_caregiver`c'_univ_el (1 = 1) (2 = 0) (6 = .) (else = .), ///
            gen(`role'_cg`c'_univ)
        label var `role'_cg`c'_univ "`who' Caregiver `c': Attended university"

        * If studies answered but univ missing, set univ = 0
        replace `role'_cg`c'_univ = 0 if !missing(`role'_caregiver`c'_studies_el) ///
            & missing(`role'_cg`c'_univ)

        * University categorical
        recode `role'_caregiver`c'_univ_el (1 = 1) (2 = 2) (6 = 3) (else = .), ///
            gen(`role'_cg`c'_univ_cat)
        label var `role'_cg`c'_univ_cat "`who' Caregiver `c' went to uni (cat)"
        label values `role'_cg`c'_univ_cat cg_edu_lbl
    }
}

********************************************************************************
*                    15. TEACHER CONTRACT AND EDUCATION                        *
********************************************************************************

* Teacher contract type
gen tch_contr_cat = (tch_type_contract_el == 2)
replace tch_contr_cat = 2 if tch_type_contract_el == 3
replace tch_contr_cat = 3 if tch_type_contract_el == 6
replace tch_contr_cat = 4 if tch_type_contract_el == 5
replace tch_contr_cat = . if tch_type_contract_el == . | tch_type_contract_el == .m
label var tch_contr_cat "Teacher Contract Type"

* Teacher education level
gen tch_edu_cat = (tch_educ_level_el == 2)
replace tch_edu_cat = 2 if tch_educ_level_el == 4
replace tch_edu_cat = 3 if tch_educ_level_el == 1
replace tch_edu_cat = 4 if tch_educ_level_el == 5
replace tch_edu_cat = . if tch_educ_level_el == . | tch_educ_level_el == .m
label var tch_edu_cat "Teacher Education"

* Recode hours dedicated (harmonize category ordering)
recode qtch_group_hours_el (1=1) (2=2) (3=4) (4=6) (5=7) (6=5) (7=3)
recode qtch_group_hours_bl (1=1) (2=2) (3=3) (4=5) (5=6) (6=4)

label define qtch_group_hours_lbl ///
    1 "1-2 hours" 2 "3-4 hours" 3 "4-5 hours" 4 "5-6 hours" ///
    5 "6-7 hours" 6 "7-8 hours" 7 "more than 8 hours", replace
label values qtch_group_hours_el qtch_group_hours_lbl
label values qtch_group_hours_bl qtch_group_hours_lbl

* ESO Cycle (grades 1-2 = Cycle 1, grades 3-4 = Cycle 2)
gen ciclo = .
replace ciclo = 0 if grade == "1" | grade == "2"
replace ciclo = 1 if grade == "3" | grade == "4"
label var ciclo "Cycle of ESO"
label define ciclo_lbl 0 "Cycle 1" 1 "Cycle 2"
label values ciclo ciclo_lbl

********************************************************************************
*                      16. ADD LABEL VARIABLES                                 *
********************************************************************************

merge m:1 pb_subdim using "$intpbobs/pbvars_con", keep(matched) nogen

* Restore original variable names for IDs
rename studid tempname
rename studcode studid
rename tempname studcode

rename obsid tmp_obs
rename obscode obsid
rename tmp_obs obscode

rename schlid tmp_sch
rename schlcode schlid
rename tmp_sch schlcode

* Define global macros for variable groups
global stu_info_new stu_male stu_fem stu_gender stu_age_years_el stu_spain ///
    stu_born_country stu_caregiver1_el stu_caregiver2_el stu_cg1_spain stu_cg2_spain ///
    stu_cg1_univ stu_cg2_univ stu_cg1_univ_cat stu_cg2_univ_cat stu_hh_socioecon_index_bl ///
    stu_lowses_index stu_careg_born_spain_dum stu_eyestest_score_bl stu_eyestest_score_el

global obs_info_new obs_male obs_fem obs_gender obs_age_years_el obs_spain ///
    obs_born_country obs_caregiver1_el obs_caregiver2_el obs_cg1_spain obs_cg2_spain ///
    obs_cg1_univ obs_cg2_univ obs_cg1_univ_cat obs_cg2_univ_cat obs_hh_socioecon_index_bl ///
    obs_lowses_index obs_eyestest_score_bl obs_eyestest_score_el

global tch_info_new tch_male tch_fem qtch_male qtch_fem tch_gender tch_age ///
    tch_contr_cat tch_edu_cat tch_group_hours_el tch_group_experience_el

********************************************************************************
*                17. RESHAPE TO WIDE FORMAT BY PB DIMENSION                    *
********************************************************************************

collapse s_std_dom, by(schlid schlcode classid municipality studid studcode pb_dim ///
    pb_type gradeclass complexity attrition grade class ciclo pairing ///
    $stu_info_new obsid obscode $obs_info_new $tch_info_new eo_fem tchcode ///
    tot_teachers_class `tch_data')

order schlid schlcode classid municipality studid studcode obsid obscode pb_dim ///
    pb_type s_std_dom stu_male stu_fem obs_male obs_fem pairing tch_male tch_fem ///
    eo_fem gradeclass ciclo complexity attrition grade class $stu_info_new ///
    $obs_info_new tchcode tot_teachers_class $tch_info_new `tch_data'

sort schlid classid studid obsid pb_type pb_dim

* Reshape to wide format
reshape wide s_std_dom, i(schlid studid obsid pb_type) j(pb_dim) string

* Rename dimension variables
local dimensions autonomy cooperation emotion responsiblity thinking
foreach dim in `dimensions' {
    rename s_std_dom`dim' s_std_`dim'
}

* Correct typo in dimension name
rename s_std_responsiblity s_std_responsibility

* Label domain variables
label var s_std_autonomy "Autonomy"
label var s_std_cooperation "Cooperation"
label var s_std_emotion "Emotional Management"
label var s_std_responsibility "Responsibility"
label var s_std_thinking "Thinking Abilities"

* Create clustering variable
gen schgradeclass = schlid + gradeclass

* Encode complexity level
encode complexity, gen(complexity_c)

********************************************************************************
*                        18. GENERATE AGGREGATED SCORES                        *
********************************************************************************

local dimensions autonomy cooperation emotion responsibility thinking

*---------------------------------------------------------------------------
* 18.1 Average Teacher Score (across all teachers per student)
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "TEACHER"
    collapse (mean) s_std_*, by(schlid studid)
    rename (s_std_autonomy s_std_cooperation s_std_emotion s_std_responsibility s_std_thinking) ///
           (tch_autonomy tch_cooperation tch_emotion tch_responsibility tch_thinking)

    label_domains tch, lbl("Teacher Score")

    tempfile teacher_means
    save `teacher_means'
restore

merge m:1 schlid studid using `teacher_means', keep(match master) nogen

*---------------------------------------------------------------------------
* 18.2 Teacher Scores by Teacher Gender
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "TEACHER"
    keep schlid studid tch_fem s_std_autonomy s_std_cooperation s_std_emotion ///
         s_std_responsibility s_std_thinking

    * Pass tch_fem (==1 for female) so program's F/M suffixes match the values
    gen_scores_by_gender tch, scorevar(s_std) gendervar(tch_fem) byvar(schlid studid) ///
        femlbl("Female Teacher Score") malelbl("Male Teacher Score")

    duplicates drop studid, force

    tempfile teacher_gender
    save `teacher_gender'
restore

merge m:1 schlid studid using `teacher_gender', keep(match master) nogen

*---------------------------------------------------------------------------
* 18.3 Student Self Score
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "SELF"
    rename (s_std_autonomy s_std_cooperation s_std_emotion s_std_responsibility s_std_thinking) ///
           (self_autonomy self_cooperation self_emotion self_responsibility self_thinking)

    duplicates drop studid, force

    tempfile self_scores
    save `self_scores', replace
restore

merge m:1 schlid studid using `self_scores', keep(match master) nogen

label_domains self, lbl("Self Score")

*---------------------------------------------------------------------------
* 18.4 Peer's Teacher Score (teacher score for the observer/peer)
*---------------------------------------------------------------------------
preserve
    keep schlid studid tch_autonomy tch_cooperation tch_emotion tch_responsibility tch_thinking ///
        tchF_autonomy tchM_autonomy tchF_cooperation tchM_cooperation tchF_emotion tchM_emotion ///
        tchF_responsibility tchM_responsibility tchF_thinking tchM_thinking
    rename studid obsid
    duplicates drop obsid, force

    foreach domain of local dimensions {
        gen obs_tch_`domain' = tch_`domain'
        gen obs_tchF_`domain' = tchF_`domain'
        gen obs_tchM_`domain' = tchM_`domain'
    }

    tempfile pb_obs_tch
    save `pb_obs_tch'
restore

merge m:1 schlid obsid using `pb_obs_tch', keep(match master) nogen

foreach d of local dimensions {
    label var obs_tch_`d' "Peer's Teacher Score: `d'"
    label var obs_tchF_`d' "Peer's Female Teacher Score: `d'"
    label var obs_tchM_`d' "Peer's Male Teacher Score: `d'"
}

*---------------------------------------------------------------------------
* 18.5 Peer's Reciprocal Score (how the peer rated the student back)
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "CO"
    keep schlid studid obsid s_std_autonomy s_std_cooperation s_std_emotion ///
         s_std_responsibility s_std_thinking

    * Swap roles: studid -> obsid, obsid -> studid
    rename studid tempobs
    rename obsid tempstud

    rename s_std_autonomy obs_autonomy
    rename s_std_cooperation obs_cooperation
    rename s_std_emotion obs_emotion
    rename s_std_responsibility obs_responsibility
    rename s_std_thinking obs_thinking

    rename tempobs obsid
    rename tempstud studid

    tempfile reversed
    save `reversed', replace
restore

merge 1:1 schlid studid obsid using `reversed', keep(match master) nogen

label_domains obs, lbl("Peer's Reciprocal Score")

*---------------------------------------------------------------------------
* 18.6 Peer's Self Score
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "SELF"
    drop studid
    rename (s_std_autonomy s_std_cooperation s_std_emotion s_std_responsibility s_std_thinking) ///
           (obs_self_autonomy obs_self_cooperation obs_self_emotion obs_self_responsibility obs_self_thinking)

    duplicates drop obsid, force

    tempfile obs_self_scores
    save `obs_self_scores', replace
restore

merge m:1 schlid obsid using `obs_self_scores', keep(match master) nogen

label_domains obs_self, lbl("Peer's Self Score")

*---------------------------------------------------------------------------
* 18.7 Student's Average Peer Score (for self-evaluation dataset)
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "CO"
    keep schlid studid obs_fem s_std_autonomy s_std_cooperation s_std_emotion ///
         s_std_responsibility s_std_thinking

    * Overall average peer score
    foreach d of local dimensions {
        egen ave_peer_`d' = mean(s_std_`d'), by(studid)
        label var ave_peer_`d' "Ave Peer Score: `d'"
    }

    * By peer gender
    foreach d of local dimensions {
        bys schlid studid: egen peerF_`d' = mean(cond(obs_fem == 1, s_std_`d', .))
        label var peerF_`d' "Female Ave Peer Score: `d'"

        bys schlid studid: egen peerM_`d' = mean(cond(obs_fem == 0, s_std_`d', .))
        label var peerM_`d' "Male Ave Peer Score: `d'"
    }

    duplicates drop studid, force

    tempfile self_peer
    save `self_peer', replace
restore

* Peer-out scores (how others rate you)
preserve
    keep if pb_type == "CO"
    keep schlid obsid stu_fem s_std_autonomy s_std_cooperation s_std_emotion ///
         s_std_responsibility s_std_thinking

    foreach d of local dimensions {
        egen ave_out_`d' = mean(s_std_`d'), by(obsid)
        label var ave_out_`d' "Ave Peer-out Score: `d'"
    }

    foreach d of local dimensions {
        bys schlid obsid: egen peerFout_`d' = mean(cond(stu_fem == 1, s_std_`d', .))
        label var peerFout_`d' "Female Ave Peer-out Score: `d'"

        bys schlid obsid: egen peerMout_`d' = mean(cond(stu_fem == 0, s_std_`d', .))
        label var peerMout_`d' "Male Ave Peer-out Score: `d'"
    }

    duplicates drop obsid, force
    rename obsid studid

    tempfile self_out
    save `self_out', replace
restore

merge m:1 schlid studid using `self_peer', keep(match master) nogen
merge m:1 schlid studid using `self_out', keep(match master) nogen

*---------------------------------------------------------------------------
* 18.8 EO (External Observer) Score
*---------------------------------------------------------------------------
preserve
    keep if pb_type == "RESEARCH"

    foreach d of local dimensions {
        egen eo_`d' = mean(s_std_`d'), by(studid)
        label var eo_`d' "EO Score: `d'"
    }

    * By EO gender
    foreach d of local dimensions {
        bys schlid studid: egen eoF_`d' = mean(cond(eo_fem == 1, s_std_`d', .))
        label var eoF_`d' "Female EO Score: `d'"

        bys schlid studid: egen eoM_`d' = mean(cond(eo_fem == 0, s_std_`d', .))
        label var eoM_`d' "Male EO Score: `d'"
    }

    duplicates drop studid, force

    tempfile eo_means
    save `eo_means'
restore

merge m:1 schlid studid using `eo_means', keep(match master) nogen

*---------------------------------------------------------------------------
* 18.9 Peer's EO Score
*---------------------------------------------------------------------------
preserve
    keep schlid studid eo_autonomy eo_cooperation eo_emotion eo_responsibility eo_thinking
    rename studid obsid
    duplicates drop obsid, force

    foreach domain of local dimensions {
        gen obs_eo_`domain' = eo_`domain'
    }

    tempfile pb_tch_eo
    save `pb_tch_eo', replace
restore

merge m:1 schlid obsid using `pb_tch_eo', keep(match master) nogen

label_domains obs_eo, lbl("Peer's EO Score")

********************************************************************************
*                       19. GENERATE DEVIATION SCORES                          *
********************************************************************************

local dimensions autonomy cooperation emotion responsibility thinking

*---------------------------------------------------------------------------
* 19.1 Peer - Teacher Deviation
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_`d' = .
    replace dev_`d' = s_std_`d' - tch_`d' if pb_type == "CO"
    label var dev_`d' "Peer - Teacher Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.2 Reciprocal Deviation (Peer - reverse peer score)
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_obs_`d' = .
    replace dev_obs_`d' = s_std_`d' - obs_`d' if pb_type == "CO"
    label var dev_obs_`d' "Peer - Student Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.3 Peer - Self Deviation
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_self_`d' = s_std_`d' - self_`d' if pb_type == "CO"
    label var dev_self_`d' "Peer - Self Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.4 Teacher - EO Deviation
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_tch_eo_`d' = .
    replace dev_tch_eo_`d' = tch_`d' - eo_`d' if pb_type == "TEACHER"
    label var dev_tch_eo_`d' "Teacher - EO Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.5 Peer - EO Deviation
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_peer_eo_`d' = s_std_`d' - eo_`d' if pb_type == "CO"
    label var dev_peer_eo_`d' "Peer - EO Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.6 Self - Average Peer Deviations (for panel analysis)
*---------------------------------------------------------------------------
foreach d of local dimensions {
    * Overall
    gen dev_self_p_`d' = self_`d' - ave_peer_`d' if pb_type == "SELF"
    label var dev_self_p_`d' "Self - Ave Peer Score Deviation: `d'"

    * By peer gender
    gen dev_self_fp_`d' = self_`d' - peerF_`d' if pb_type == "SELF"
    label var dev_self_fp_`d' "Self - Fem Ave Peer Score Deviation: `d'"

    gen dev_self_mp_`d' = self_`d' - peerM_`d' if pb_type == "SELF"
    label var dev_self_mp_`d' "Self - Male Ave Peer Score Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.7 Self - Average Peer-out Deviations
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_self_out_`d' = self_`d' - ave_out_`d' if pb_type == "SELF"
    label var dev_self_out_`d' "Self - Ave Peer Out Score Deviation: `d'"

    gen dev_self_fout_`d' = self_`d' - peerFout_`d' if pb_type == "SELF"
    label var dev_self_fout_`d' "Self - Fem Ave Peer Score Deviation: `d'"

    gen dev_self_mout_`d' = self_`d' - peerMout_`d' if pb_type == "SELF"
    label var dev_self_mout_`d' "Self - Male Ave Peer Score Deviation: `d'"
}

*---------------------------------------------------------------------------
* 19.8 Self - Teacher Deviations
*---------------------------------------------------------------------------
foreach d of local dimensions {
    gen dev_self_tch_`d' = self_`d' - tch_`d' if pb_type == "SELF"
    label var dev_self_tch_`d' "Self - Teacher Deviation: `d'"

    gen dev_self_tchF_`d' = self_`d' - tchF_`d' if pb_type == "SELF"
    label var dev_self_tchF_`d' "Self - Fem Tch Deviation: `d'"

    gen dev_self_tchM_`d' = self_`d' - tchM_`d' if pb_type == "SELF"
    label var dev_self_tchM_`d' "Self - Male Tch Deviation: `d'"
}

********************************************************************************
*                    20. FINAL SAMPLE RESTRICTIONS AND SAVE                    *
********************************************************************************

* Drop attrition classes
qui count if attrition == "Yes"
local n_attrition = r(N)
drop if attrition == "Yes"
di as text "Dropped `n_attrition' observations from attrition classes"

* Final validation
qui count
local final_obs = r(N)
di as text "Final dataset: `final_obs' observations"

* Validate key variables
qui count if missing(stu_male) & pb_type == "CO"
if r(N) > 0 {
    di as error "WARNING: `r(N)' CO observations with missing student gender"
}

qui count if missing(obs_male) & pb_type == "CO"
if r(N) > 0 {
    di as error "WARNING: `r(N)' CO observations with missing observer gender"
}

* Summary statistics
di as text _n "=== FINAL DATASET SUMMARY ==="
di as text "Observations by pb_type:"
tab pb_type

di as text _n "Gender pairing distribution (CO only):"
tab pairing if pb_type == "CO"

* Save final dataset
save "$cleanpb/class/pb_4s_all_new.dta", replace

di as text _n "Dataset saved to: " as result "$cleanpb/class/pb_4s_all_new.dta"

********************************************************************************
*                              END OF FILE                                     *
********************************************************************************
