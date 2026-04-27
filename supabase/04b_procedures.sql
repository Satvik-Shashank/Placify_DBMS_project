-- =============================================================================
-- PLACIFY — SUPABASE STORED PROCEDURES (as PostgreSQL functions)
-- Run AFTER 04_triggers.sql, BEFORE 05_seed.sql
-- =============================================================================
-- PostgreSQL uses functions (not procedures) to return result sets.
-- OUT params become function return values.
-- =============================================================================

-- PROCEDURE 1: sp_apply_for_company
-- Returns: (application_id INT, message TEXT)
CREATE OR REPLACE FUNCTION sp_apply_for_company(
    p_student_id INT, p_company_id INT
) RETURNS TABLE(application_id INT, message TEXT) AS $$
DECLARE
    v_is_placed BOOLEAN; v_cgpa DECIMAL(4,2); v_backlogs INT; v_dept TEXT;
    v_min_cgpa DECIMAL(4,2); v_max_backlogs INT; v_allowed JSONB;
    v_ctc DECIMAL(10,2); v_is_dream BOOLEAN; v_deadline TIMESTAMP; v_status TEXT;
    v_dup INT; v_app_id INT;
BEGIN
    SELECT s.is_placed, s.cgpa, s.backlogs, s.department::TEXT
    INTO v_is_placed, v_cgpa, v_backlogs, v_dept
    FROM students s WHERE s.student_id = p_student_id FOR UPDATE;
    IF NOT FOUND THEN RETURN QUERY SELECT 0, 'Student not found'::TEXT; RETURN; END IF;

    SELECT c.ctc_lpa, c.is_dream, c.registration_deadline, c.status::TEXT
    INTO v_ctc, v_is_dream, v_deadline, v_status
    FROM companies c WHERE c.company_id = p_company_id FOR UPDATE;
    IF NOT FOUND THEN RETURN QUERY SELECT 0, 'Company not found'::TEXT; RETURN; END IF;

    IF v_status != 'upcoming' THEN RETURN QUERY SELECT 0, 'Company registration is closed'::TEXT; RETURN; END IF;
    IF NOW() > v_deadline THEN RETURN QUERY SELECT 0, 'Registration deadline has passed'::TEXT; RETURN; END IF;

    SELECT COUNT(*) INTO v_dup FROM applications a WHERE a.student_id = p_student_id AND a.company_id = p_company_id;
    IF v_dup > 0 THEN RETURN QUERY SELECT 0, 'Already applied to this company'::TEXT; RETURN; END IF;

    SELECT e.min_cgpa, e.max_backlogs, e.allowed_departments
    INTO v_min_cgpa, v_max_backlogs, v_allowed
    FROM eligibility_criteria e WHERE e.company_id = p_company_id;

    IF v_cgpa < v_min_cgpa THEN RETURN QUERY SELECT 0, ('CGPA requirement not met. Required: ' || v_min_cgpa)::TEXT; RETURN; END IF;
    IF v_backlogs > v_max_backlogs THEN RETURN QUERY SELECT 0, ('Too many backlogs. Maximum allowed: ' || v_max_backlogs)::TEXT; RETURN; END IF;
    IF NOT v_allowed ? v_dept THEN RETURN QUERY SELECT 0, ('Department not eligible: ' || v_dept)::TEXT; RETURN; END IF;
    IF v_is_placed AND NOT v_is_dream THEN RETURN QUERY SELECT 0, 'Already placed. Can only apply to dream companies'::TEXT; RETURN; END IF;

    INSERT INTO applications (student_id, company_id, status, applied_at)
    VALUES (p_student_id, p_company_id, 'applied', NOW()) RETURNING applications.application_id INTO v_app_id;

    RETURN QUERY SELECT v_app_id, 'Application submitted successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 2: sp_accept_offer
CREATE OR REPLACE FUNCTION sp_accept_offer(p_offer_id INT)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_app_id INT; v_student_id INT; v_company_id INT;
    v_offer_status TEXT; v_is_dream BOOLEAN;
BEGIN
    SELECT o.application_id, o.status::TEXT, o.offered_ctc, a.student_id, a.company_id
    INTO v_app_id, v_offer_status, _, v_student_id, v_company_id
    FROM offers o JOIN applications a ON o.application_id = a.application_id
    WHERE o.offer_id = p_offer_id FOR UPDATE;
    IF NOT FOUND THEN RETURN QUERY SELECT FALSE, 'Offer not found'::TEXT; RETURN; END IF;
    IF v_offer_status != 'pending' THEN RETURN QUERY SELECT FALSE, 'Offer already processed'::TEXT; RETURN; END IF;

    SELECT c.is_dream INTO v_is_dream FROM companies c WHERE c.company_id = v_company_id;

    UPDATE offers SET status = 'accepted', accepted_at = NOW(), updated_at = NOW() WHERE offer_id = p_offer_id;
    UPDATE students SET is_placed = TRUE,
        placement_type = CASE WHEN v_is_dream THEN 'dream'::placement_type ELSE 'regular'::placement_type END,
        updated_at = NOW() WHERE student_id = v_student_id;

    UPDATE offers SET status = 'declined', updated_at = NOW()
    FROM applications a2 WHERE offers.application_id = a2.application_id
    AND a2.student_id = v_student_id AND offers.offer_id != p_offer_id AND offers.status = 'pending';

    UPDATE applications SET status = 'withdrawn', updated_at = NOW()
    WHERE student_id = v_student_id AND status IN ('applied', 'in_progress') AND company_id != v_company_id;

    RETURN QUERY SELECT TRUE, 'Offer accepted successfully. All other applications withdrawn.'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 3: sp_decline_offer
CREATE OR REPLACE FUNCTION sp_decline_offer(p_offer_id INT)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE v_status TEXT;
BEGIN
    SELECT o.status::TEXT INTO v_status FROM offers o WHERE o.offer_id = p_offer_id FOR UPDATE;
    IF NOT FOUND THEN RETURN QUERY SELECT FALSE, 'Offer not found'::TEXT; RETURN; END IF;
    IF v_status != 'pending' THEN RETURN QUERY SELECT FALSE, 'Offer cannot be declined - already processed'::TEXT; RETURN; END IF;
    UPDATE offers SET status = 'declined', updated_at = NOW() WHERE offer_id = p_offer_id;
    RETURN QUERY SELECT TRUE, 'Offer declined successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 4: sp_withdraw_application
CREATE OR REPLACE FUNCTION sp_withdraw_application(p_application_id INT)
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE v_status TEXT; v_has_offer INT;
BEGIN
    SELECT a.status::TEXT INTO v_status FROM applications a WHERE a.application_id = p_application_id FOR UPDATE;
    IF NOT FOUND THEN RETURN QUERY SELECT FALSE, 'Application not found'::TEXT; RETURN; END IF;
    IF v_status IN ('rejected', 'withdrawn') THEN RETURN QUERY SELECT FALSE, 'Application already closed'::TEXT; RETURN; END IF;
    SELECT COUNT(*) INTO v_has_offer FROM offers WHERE application_id = p_application_id AND status = 'pending';
    IF v_has_offer > 0 THEN RETURN QUERY SELECT FALSE, 'Cannot withdraw - pending offer exists. Decline offer first.'::TEXT; RETURN; END IF;
    UPDATE applications SET status = 'withdrawn', updated_at = NOW() WHERE application_id = p_application_id;
    RETURN QUERY SELECT TRUE, 'Application withdrawn successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 5: sp_get_eligible_companies (cursor-based in MySQL, set-based here)
CREATE OR REPLACE FUNCTION sp_get_eligible_companies(p_student_id INT)
RETURNS TABLE(
    company_id INT, company_name VARCHAR, ctc_lpa DECIMAL, is_dream BOOLEAN,
    visit_date DATE, registration_deadline TIMESTAMP, eligibility_status TEXT
) AS $$
DECLARE
    v_cgpa DECIMAL(4,2); v_backlogs INT; v_dept TEXT; v_is_placed BOOLEAN;
BEGIN
    SELECT s.cgpa, s.backlogs, s.department::TEXT, s.is_placed
    INTO v_cgpa, v_backlogs, v_dept, v_is_placed
    FROM students s WHERE s.student_id = p_student_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Student not found'; END IF;

    RETURN QUERY
    SELECT c.company_id, c.name::VARCHAR, c.ctc_lpa, c.is_dream, c.visit_date, c.registration_deadline,
        CASE
            WHEN v_cgpa < e.min_cgpa THEN 'Not Eligible - Low CGPA'
            WHEN v_backlogs > e.max_backlogs THEN 'Not Eligible - Backlogs'
            WHEN NOT e.allowed_departments ? v_dept THEN 'Not Eligible - Department'
            WHEN v_is_placed AND NOT c.is_dream THEN 'Not Eligible - Already Placed'
            WHEN EXISTS(SELECT 1 FROM applications a WHERE a.student_id = p_student_id AND a.company_id = c.company_id) THEN 'Already Applied'
            ELSE 'Eligible'
        END::TEXT
    FROM companies c
    JOIN eligibility_criteria e ON c.company_id = e.company_id
    WHERE c.status = 'upcoming' AND c.registration_deadline > NOW()
    ORDER BY c.visit_date;
END;
$$ LANGUAGE plpgsql;
