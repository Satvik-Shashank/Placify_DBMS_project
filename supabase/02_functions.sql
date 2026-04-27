-- =============================================================================
-- PLACIFY — SUPABASE FUNCTIONS (PostgreSQL)
-- Run SECOND in Supabase SQL Editor
-- =============================================================================

-- FUNCTION 1: Calculate eligibility score
CREATE OR REPLACE FUNCTION fn_calculate_eligibility_score(p_student_id INT, p_company_id INT)
RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_cgpa DECIMAL(4,2); v_backlogs INT;
    v_min_cgpa DECIMAL(4,2); v_max_backlogs INT;
BEGIN
    SELECT cgpa, backlogs INTO v_cgpa, v_backlogs FROM students WHERE student_id = p_student_id;
    SELECT min_cgpa, max_backlogs INTO v_min_cgpa, v_max_backlogs FROM eligibility_criteria WHERE company_id = p_company_id;
    IF v_cgpa < v_min_cgpa OR v_backlogs > v_max_backlogs THEN RETURN 0.00; END IF;
    RETURN (v_cgpa / 10.0) * 70.0 + GREATEST(0, 30 - (v_backlogs * 10));
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 2: Get student's highest accepted package
CREATE OR REPLACE FUNCTION fn_get_student_highest_package(p_student_id INT)
RETURNS DECIMAL(10,2) AS $$
DECLARE v_pkg DECIMAL(10,2);
BEGIN
    SELECT MAX(o.offered_ctc) INTO v_pkg
    FROM offers o JOIN applications a ON o.application_id = a.application_id
    WHERE a.student_id = p_student_id AND o.status = 'accepted';
    RETURN COALESCE(v_pkg, 0.00);
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 3: Check dream eligibility
CREATE OR REPLACE FUNCTION fn_check_dream_eligibility(p_student_id INT, p_company_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_is_placed BOOLEAN; v_is_dream BOOLEAN;
    v_current_pkg DECIMAL(10,2); v_new_pkg DECIMAL(10,2);
    v_dream_min DECIMAL(10,2);
BEGIN
    SELECT is_placed INTO v_is_placed FROM students WHERE student_id = p_student_id;
    IF v_is_placed = FALSE THEN RETURN TRUE; END IF;
    SELECT is_dream, ctc_lpa INTO v_is_dream, v_new_pkg FROM companies WHERE company_id = p_company_id;
    IF v_is_dream = FALSE THEN RETURN FALSE; END IF;
    v_current_pkg := fn_get_student_highest_package(p_student_id);
    SELECT dream_min_ctc INTO v_dream_min FROM eligibility_criteria WHERE company_id = p_company_id;
    IF v_new_pkg > v_current_pkg THEN
        IF v_dream_min IS NULL OR v_new_pkg >= v_dream_min THEN RETURN TRUE; END IF;
    END IF;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 4: Department placement percentage
CREATE OR REPLACE FUNCTION fn_get_department_placement_percentage(p_dept VARCHAR, p_year INT)
RETURNS DECIMAL(5,2) AS $$
DECLARE v_total INT; v_placed INT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM students WHERE department = p_dept::department_type AND batch_year = p_year;
    IF v_total = 0 THEN RETURN 0.00; END IF;
    SELECT COUNT(*) INTO v_placed FROM students WHERE department = p_dept::department_type AND batch_year = p_year AND is_placed = TRUE;
    RETURN (v_placed::DECIMAL / v_total) * 100.0;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 5: Company avg package
CREATE OR REPLACE FUNCTION fn_get_company_avg_package(p_company_id INT)
RETURNS DECIMAL(10,2) AS $$
DECLARE v_avg DECIMAL(10,2);
BEGIN
    SELECT AVG(o.offered_ctc) INTO v_avg FROM offers o
    JOIN applications a ON o.application_id = a.application_id
    WHERE a.company_id = p_company_id AND o.status = 'accepted';
    RETURN COALESCE(v_avg, 0.00);
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 6: Count active applications
CREATE OR REPLACE FUNCTION fn_count_active_applications(p_student_id INT)
RETURNS INT AS $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM applications
    WHERE student_id = p_student_id AND status IN ('applied', 'in_progress', 'selected');
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 7: Check application exists
CREATE OR REPLACE FUNCTION fn_check_application_exists(p_student_id INT, p_company_id INT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS(SELECT 1 FROM applications WHERE student_id = p_student_id AND company_id = p_company_id);
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 8: Get placement rank
CREATE OR REPLACE FUNCTION fn_get_placement_rank(p_student_id INT, p_batch_year INT)
RETURNS INT AS $$
DECLARE v_pkg DECIMAL(10,2); v_rank INT;
BEGIN
    v_pkg := fn_get_student_highest_package(p_student_id);
    IF v_pkg = 0 THEN RETURN 0; END IF;
    SELECT COUNT(*) + 1 INTO v_rank FROM students s
    WHERE s.batch_year = p_batch_year AND s.is_placed = TRUE
    AND fn_get_student_highest_package(s.student_id) > v_pkg;
    RETURN v_rank;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 9: Total offers count for company
CREATE OR REPLACE FUNCTION fn_get_total_offers_count(p_company_id INT)
RETURNS INT AS $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM offers o
    JOIN applications a ON o.application_id = a.application_id
    WHERE a.company_id = p_company_id;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- FUNCTION 10: Check all rounds cleared
CREATE OR REPLACE FUNCTION fn_check_all_rounds_cleared(p_application_id INT)
RETURNS BOOLEAN AS $$
DECLARE v_company_id INT;
BEGIN
    SELECT company_id INTO v_company_id FROM applications WHERE application_id = p_application_id;
    RETURN NOT EXISTS(
        SELECT 1 FROM rounds r WHERE r.company_id = v_company_id
        AND NOT EXISTS(
            SELECT 1 FROM round_results rr WHERE rr.round_id = r.round_id
            AND rr.application_id = p_application_id AND rr.status = 'shortlisted'
        )
    );
END;
$$ LANGUAGE plpgsql;
