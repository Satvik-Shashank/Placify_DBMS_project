-- =============================================================================
-- PLACIFY — SUPABASE TRIGGERS (PostgreSQL)
-- Run FOURTH in Supabase SQL Editor
-- =============================================================================

-- TRIGGER 1: Validate and normalize user email before insert
CREATE OR REPLACE FUNCTION trg_users_before_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email NOT LIKE '%@%.%' THEN RAISE EXCEPTION 'Invalid email format'; END IF;
    NEW.email := LOWER(NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_users_before_insert BEFORE INSERT ON users FOR EACH ROW EXECUTE FUNCTION trg_users_before_insert_fn();

-- TRIGGER 2: Audit log on user creation
CREATE OR REPLACE FUNCTION trg_users_after_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (table_name, action_type, record_id, user_id, user_role, new_values)
    VALUES ('users', 'INSERT', NEW.user_id, NEW.user_id, NEW.role::TEXT,
        jsonb_build_object('email', NEW.email, 'role', NEW.role::TEXT, 'is_active', NEW.is_active));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_users_after_insert AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION trg_users_after_insert_fn();

-- TRIGGER 3: Validate student data before insert
CREATE OR REPLACE FUNCTION trg_students_before_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cgpa < 0 OR NEW.cgpa > 10 THEN RAISE EXCEPTION 'CGPA must be between 0 and 10'; END IF;
    IF NEW.backlogs < 0 THEN RAISE EXCEPTION 'Backlogs cannot be negative'; END IF;
    IF NEW.batch_year < 2020 OR NEW.batch_year > 2030 THEN RAISE EXCEPTION 'Invalid batch year'; END IF;
    IF NEW.phone !~ '^[0-9]{10}$' THEN RAISE EXCEPTION 'Phone must be 10 digits'; END IF;
    NEW.email := LOWER(NEW.email);
    NEW.is_placed := FALSE;
    NEW.placement_type := NULL;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_students_before_insert BEFORE INSERT ON students FOR EACH ROW EXECUTE FUNCTION trg_students_before_insert_fn();

-- TRIGGER 4: Log placement status changes
CREATE OR REPLACE FUNCTION trg_students_after_update_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.is_placed IS DISTINCT FROM NEW.is_placed OR OLD.placement_type IS DISTINCT FROM NEW.placement_type THEN
        INSERT INTO audit_logs (table_name, action_type, record_id, user_id, user_role, old_values, new_values)
        VALUES ('students', 'UPDATE', NEW.student_id, NEW.user_id, 'student',
            jsonb_build_object('is_placed', OLD.is_placed, 'placement_type', OLD.placement_type::TEXT),
            jsonb_build_object('is_placed', NEW.is_placed, 'placement_type', NEW.placement_type::TEXT));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_students_after_update AFTER UPDATE ON students FOR EACH ROW EXECUTE FUNCTION trg_students_after_update_fn();

-- TRIGGER 5: Validate company before insert
CREATE OR REPLACE FUNCTION trg_companies_before_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ctc_lpa <= 0 THEN RAISE EXCEPTION 'CTC must be positive'; END IF;
    IF NEW.website IS NOT NULL AND NEW.website NOT LIKE 'http%' THEN RAISE EXCEPTION 'Website must start with http'; END IF;
    IF NEW.status IS NULL THEN NEW.status := 'upcoming'; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_companies_before_insert BEFORE INSERT ON companies FOR EACH ROW EXECUTE FUNCTION trg_companies_before_insert_fn();

-- TRIGGER 6: Prevent duplicate applications
CREATE OR REPLACE FUNCTION trg_applications_before_insert_fn()
RETURNS TRIGGER AS $$
DECLARE v_dup INT;
BEGIN
    SELECT COUNT(*) INTO v_dup FROM applications WHERE student_id = NEW.student_id AND company_id = NEW.company_id;
    IF v_dup > 0 THEN RAISE EXCEPTION 'Duplicate application detected'; END IF;
    IF NEW.status IS NULL THEN NEW.status := 'applied'; END IF;
    NEW.applied_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_applications_before_insert BEFORE INSERT ON applications FOR EACH ROW EXECUTE FUNCTION trg_applications_before_insert_fn();

-- TRIGGER 7: Audit log on application creation
CREATE OR REPLACE FUNCTION trg_applications_after_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (table_name, action_type, record_id, user_id, user_role, new_values)
    VALUES ('applications', 'INSERT', NEW.application_id,
        (SELECT user_id FROM students WHERE student_id = NEW.student_id), 'student',
        jsonb_build_object('student_id', NEW.student_id, 'company_id', NEW.company_id, 'status', NEW.status::TEXT));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_applications_after_insert AFTER INSERT ON applications FOR EACH ROW EXECUTE FUNCTION trg_applications_after_insert_fn();

-- TRIGGER 8: Log application status changes
CREATE OR REPLACE FUNCTION trg_applications_after_update_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO audit_logs (table_name, action_type, record_id, user_id, user_role, old_values, new_values)
        VALUES ('applications', 'UPDATE', NEW.application_id,
            (SELECT user_id FROM students WHERE student_id = NEW.student_id), 'student',
            jsonb_build_object('status', OLD.status::TEXT), jsonb_build_object('status', NEW.status::TEXT));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_applications_after_update AFTER UPDATE ON applications FOR EACH ROW EXECUTE FUNCTION trg_applications_after_update_fn();

-- TRIGGER 9: Validate offer before insert
CREATE OR REPLACE FUNCTION trg_offers_before_insert_fn()
RETURNS TRIGGER AS $$
DECLARE v_dup INT;
BEGIN
    IF NEW.offered_ctc <= 0 THEN RAISE EXCEPTION 'Offered CTC must be positive'; END IF;
    SELECT COUNT(*) INTO v_dup FROM offers WHERE application_id = NEW.application_id;
    IF v_dup > 0 THEN RAISE EXCEPTION 'Offer already exists for this application'; END IF;
    IF NEW.status IS NULL THEN NEW.status := 'pending'; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_offers_before_insert BEFORE INSERT ON offers FOR EACH ROW EXECUTE FUNCTION trg_offers_before_insert_fn();

-- TRIGGER 10: Audit log on offer creation
CREATE OR REPLACE FUNCTION trg_offers_after_insert_fn()
RETURNS TRIGGER AS $$
DECLARE v_uid INT;
BEGIN
    SELECT s.user_id INTO v_uid FROM applications a JOIN students s ON a.student_id = s.student_id WHERE a.application_id = NEW.application_id;
    INSERT INTO audit_logs (table_name, action_type, record_id, user_id, user_role, new_values)
    VALUES ('offers', 'INSERT', NEW.offer_id, v_uid, 'student',
        jsonb_build_object('application_id', NEW.application_id, 'offered_ctc', NEW.offered_ctc, 'status', NEW.status::TEXT));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_offers_after_insert AFTER INSERT ON offers FOR EACH ROW EXECUTE FUNCTION trg_offers_after_insert_fn();

-- TRIGGER 11: Audit log on offer acceptance
CREATE OR REPLACE FUNCTION trg_offers_after_update_fn()
RETURNS TRIGGER AS $$
DECLARE v_uid INT;
BEGIN
    IF OLD.status::TEXT != 'accepted' AND NEW.status::TEXT = 'accepted' THEN
        SELECT s.user_id INTO v_uid FROM applications a JOIN students s ON a.student_id = s.student_id WHERE a.application_id = NEW.application_id;
        INSERT INTO audit_logs (table_name, action_type, record_id, user_id, user_role, old_values, new_values)
        VALUES ('offers', 'UPDATE', NEW.offer_id, v_uid, 'student',
            jsonb_build_object('status', OLD.status::TEXT),
            jsonb_build_object('status', NEW.status::TEXT, 'accepted_at', NEW.accepted_at::TEXT));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_offers_after_update AFTER UPDATE ON offers FOR EACH ROW EXECUTE FUNCTION trg_offers_after_update_fn();

-- TRIGGER 12: Validate round results
CREATE OR REPLACE FUNCTION trg_round_results_before_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.score IS NOT NULL AND (NEW.score < 0 OR NEW.score > 100) THEN RAISE EXCEPTION 'Score must be between 0 and 100'; END IF;
    IF NEW.status IS NULL THEN NEW.status := 'pending'; END IF;
    IF NEW.status::TEXT = 'absent' THEN NEW.attended := FALSE; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_round_results_before_insert BEFORE INSERT ON round_results FOR EACH ROW EXECUTE FUNCTION trg_round_results_before_insert_fn();

-- TRIGGER 13: Cascade round result status to application
CREATE OR REPLACE FUNCTION trg_round_results_after_update_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status::TEXT = 'pending' AND NEW.status::TEXT = 'rejected' THEN
        UPDATE applications SET status = 'rejected', updated_at = NOW() WHERE application_id = NEW.application_id;
    END IF;
    IF OLD.status::TEXT != 'shortlisted' AND NEW.status::TEXT = 'shortlisted' THEN
        UPDATE applications SET status = 'in_progress', updated_at = NOW() WHERE application_id = NEW.application_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_round_results_after_update AFTER UPDATE ON round_results FOR EACH ROW EXECUTE FUNCTION trg_round_results_after_update_fn();

-- TRIGGER 14: Validate eligibility criteria
CREATE OR REPLACE FUNCTION trg_eligibility_before_insert_fn()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.min_cgpa < 0 OR NEW.min_cgpa > 10 THEN RAISE EXCEPTION 'Min CGPA must be between 0 and 10'; END IF;
    IF NEW.max_backlogs < 0 THEN RAISE EXCEPTION 'Max backlogs cannot be negative'; END IF;
    IF NEW.dream_min_ctc IS NOT NULL AND NEW.dream_min_ctc <= 0 THEN RAISE EXCEPTION 'Dream min CTC must be positive'; END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_eligibility_before_insert BEFORE INSERT ON eligibility_criteria FOR EACH ROW EXECUTE FUNCTION trg_eligibility_before_insert_fn();
