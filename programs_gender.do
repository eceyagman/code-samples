********************************************************************************
*                    SHARED PROGRAMS FOR GENDER GAP ANALYSIS                   *
********************************************************************************
/*
* Creator:        Ece Yagman
* Purpose:        Define reusable Stata programs for gender gap papers
* Last modified:  17/02/2026
*
* PROGRAMS DEFINED:
*   1. gen_gender_binaries    - Create male/female indicators from gender var
*   2. gen_scores_by_gender   - Create average scores by gender subgroups
*   3. label_domains          - Label domain variables with consistent prefix
*   4. validate_merge         - Validate and report merge results
*   5. validate_observations  - Count and display observations at checkpoints
*/
********************************************************************************

********************************************************************************
*                         GENDER VARIABLE PROGRAMS                             *
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

********************************************************************************
*                         SCORE CALCULATION PROGRAMS                           *
********************************************************************************

* Program: Generate scores by gender subgroups
* Usage: gen_scores_by_gender prefix, scorevar(stub) gendervar(varname) byvar(varlist) femlbl(string) malelbl(string)
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
*                         VALIDATION PROGRAMS                                  *
********************************************************************************

* Program: Validate merge results
* Usage: validate_merge mergename, [expected_match_rate(real)] [warn_only]
capture program drop validate_merge
program define validate_merge
    syntax namelist(max=1), [expected_match_rate(real 0)] [warn_only]

    local mergename `namelist'

    qui count
    local total = r(N)
    qui count if _merge == 3
    local matched = r(N)
    qui count if _merge == 1
    local master_only = r(N)
    qui count if _merge == 2
    local using_only = r(N)

    local match_rate = `matched' / `total' * 100

    di as text _n "=== Merge Diagnostics: `mergename' ==="
    di as text "Master only: " as result `master_only'
    di as text "Using only:  " as result `using_only'
    di as text "Matched:     " as result `matched'
    di as text "Match rate:  " as result %5.1f `match_rate' "%"

    if `expected_match_rate' > 0 & `match_rate' < `expected_match_rate' {
        if "`warn_only'" != "" {
            di as error "WARNING: Match rate below expected (`expected_match_rate'%)"
        }
        else {
            di as error "ERROR: Match rate below expected (`expected_match_rate'%)"
            error 459
        }
    }
end

* Program: Validate observations at checkpoints
* Usage: validate_observations checkpoint_name, [min(integer)]
capture program drop validate_observations
program define validate_observations
    syntax namelist(max=1), [min(integer 0)]

    local checkpoint `namelist'

    qui count
    local n = r(N)

    di as text "[`checkpoint'] Observations: " as result `n'

    if `min' > 0 & `n' < `min' {
        di as error "ERROR: Fewer than `min' observations at `checkpoint'"
        error 459
    }
end

********************************************************************************
di as text "Gender gap analysis programs loaded successfully"
********************************************************************************
