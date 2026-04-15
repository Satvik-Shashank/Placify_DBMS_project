-- =============================================================================
-- PLACIFY - STORED PROCEDURES
-- File: procedures.sql
-- =============================================================================
-- SYLLABUS MAPPING: Procedures, Transactions, Exception Handling, Cursors
-- =============================================================================

USE campus_placement;

DELIMITER $$

-- =============================================================================
-- PROCEDURE 1: sp_apply_for_company
-- =============================================================================
-- SYLLABUS: Transaction Control, Exception Handling, Concurrency Control
-- DEMONSTRATES: START TRANSACTION, COMMIT, ROLLBACK, SIGNAL SQLSTATE,
--               SELECT FOR UPDATE (row locking)
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_apply_for_company$$

CREATE PROCEDURE sp_apply_for_company(
    IN p_student_id INT,
    IN p_company_id INT,
    OUT p_application_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    -- Exception handler variables
    
    
    -- Variables
    DECLARE v_is_placed BOOLEAN;
    DECLARE v_student_cgpa DECIMAL(4,2);
    DECLARE v_student_backlogs INT;
    DECLARE v_student_dept VARCHAR(10);
    DECLARE v_min_cgpa DECIMAL(4,2);
    DECLARE v_max_backlogs INT;
    DECLARE v_allowed_depts JSON;
    DECLARE v_company_ctc DECIMAL(10,2);
    DECLARE v_is_dream BOOLEAN;
    DECLARE v_deadline DATETIME;
    DECLARE v_company_status VARCHAR(20);
    DECLARE v_duplicate_count INT;
    
    -- START TRANSACTION (TCL)
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    -- Step 1: Lock student row for reading (CONCURRENCY CONTROL)
    -- SELECT ... FOR UPDATE prevents race conditions
    SELECT is_placed, cgpa, backlogs, department
    INTO v_is_placed, v_student_cgpa, v_student_backlogs, v_student_dept
    FROM students
    WHERE student_id = p_student_id
    FOR UPDATE;
    
    -- Check if student exists
    IF v_student_cgpa IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Student not found';
    END IF;
    
    -- Step 2: Get company details with lock
    SELECT ctc_lpa, is_dream, registration_deadline, status
    INTO v_company_ctc, v_is_dream, v_deadline, v_company_status
    FROM companies
    WHERE company_id = p_company_id
    FOR UPDATE;
    
    -- Check if company exists
    IF v_company_ctc IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Company not found';
    END IF;
    
    -- Step 3: Check company status
    IF v_company_status != 'upcoming' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Company registration is closed';
    END IF;
    
    -- Step 4: Check deadline
    IF NOW() > v_deadline THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Registration deadline has passed';
    END IF;
    
    -- Step 5: Check duplicate application (defensive check)
    SELECT COUNT(*)
    INTO v_duplicate_count
    FROM applications
    WHERE student_id = p_student_id AND company_id = p_company_id;
    
    IF v_duplicate_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Already applied to this company';
    END IF;
    
    -- Step 6: Get eligibility criteria
    SELECT min_cgpa, max_backlogs, allowed_departments
    INTO v_min_cgpa, v_max_backlogs, v_allowed_depts
    FROM eligibility_criteria
    WHERE company_id = p_company_id;
    
    -- Step 7: Check CGPA eligibility
    IF v_student_cgpa < v_min_cgpa THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('CGPA requirement not met. Required: ', v_min_cgpa);
    END IF;
    
    -- Step 8: Check backlogs eligibility
    IF v_student_backlogs > v_max_backlogs THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Too many backlogs. Maximum allowed: ', v_max_backlogs);
    END IF;
    
    -- Step 9: Check department eligibility using JSON_CONTAINS
    IF NOT JSON_CONTAINS(v_allowed_depts, CONCAT('"', v_student_dept, '"')) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = CONCAT('Department not eligible: ', v_student_dept);
    END IF;
    
    -- Step 10: Placement policy check
    -- If student is already placed, only allow dream company applications
    IF v_is_placed = TRUE THEN
        IF v_is_dream = FALSE THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Already placed. Can only apply to dream companies';
        END IF;
        
        -- Additional dream company validation can be added
        -- e.g., check if new package is higher than current
    END IF;
    
    -- Step 11: All checks passed - create application (DML - INSERT)
    INSERT INTO applications (student_id, company_id, status, applied_at)
    VALUES (p_student_id, p_company_id, 'applied', NOW());
    
    -- Get the generated ID
    SET p_application_id = LAST_INSERT_ID();
    SET p_message = 'Application submitted successfully';
    
    -- COMMIT transaction (TCL)
    COMMIT;
    
END$$

-- =============================================================================
-- PROCEDURE 2: sp_update_round_result
-- =============================================================================
-- SYLLABUS: Transaction, DML (INSERT/UPDATE), Business Logic
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_update_round_result$$

CREATE PROCEDURE sp_update_round_result(
    IN p_round_id INT,
    IN p_application_id INT,
    IN p_status VARCHAR(20),
    IN p_score DECIMAL(5,2),
    IN p_feedback TEXT,
    IN p_attended BOOLEAN,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    
    
    DECLARE v_result_exists INT;
    DECLARE v_application_status VARCHAR(20);
    
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    -- Validate application status
    SELECT status INTO v_application_status
    FROM applications
    WHERE application_id = p_application_id
    FOR UPDATE;
    
    IF v_application_status IN ('rejected', 'withdrawn') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot update result for rejected/withdrawn application';
    END IF;
    
    -- Check if result exists
    SELECT COUNT(*) INTO v_result_exists
    FROM round_results
    WHERE round_id = p_round_id AND application_id = p_application_id;
    
    IF v_result_exists > 0 THEN
        -- UPDATE existing result (DML - UPDATE)
        UPDATE round_results
        SET 
            status = p_status,
            score = p_score,
            feedback = p_feedback,
            attended = p_attended,
            updated_at = NOW()
        WHERE round_id = p_round_id AND application_id = p_application_id;
    ELSE
        -- INSERT new result (DML - INSERT)
        INSERT INTO round_results (
            round_id, application_id, status, score, feedback, attended
        ) VALUES (
            p_round_id, p_application_id, p_status, p_score, p_feedback, p_attended
        );
    END IF;
    
    -- Update application status if rejected
    IF p_status = 'rejected' THEN
        UPDATE applications
        SET status = 'rejected', updated_at = NOW()
        WHERE application_id = p_application_id;
    ELSIF p_status = 'shortlisted' THEN
        UPDATE applications
        SET status = 'in_progress', updated_at = NOW()
        WHERE application_id = p_application_id;
    END IF;
    
    SET p_success = TRUE;
    SET p_message = 'Round result updated successfully';
    
    COMMIT;
END$$

-- =============================================================================
-- PROCEDURE 3: sp_create_offer
-- =============================================================================
-- SYLLABUS: Transaction, Validation, DML
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_create_offer$$

CREATE PROCEDURE sp_create_offer(
    IN p_application_id INT,
    IN p_offered_ctc DECIMAL(10,2),
    IN p_offered_role VARCHAR(100),
    IN p_job_location VARCHAR(100),
    IN p_joining_date DATE,
    IN p_acceptance_deadline DATETIME,
    OUT p_offer_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    
    
    DECLARE v_application_status VARCHAR(20);
    DECLARE v_existing_offer_id INT;
    
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    -- Check application status
    SELECT status INTO v_application_status
    FROM applications
    WHERE application_id = p_application_id
    FOR UPDATE;
    
    IF v_application_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Application not found';
    END IF;
    
    IF v_application_status = 'rejected' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot create offer for rejected application';
    END IF;
    
    -- Check if offer already exists
    SELECT offer_id INTO v_existing_offer_id
    FROM offers
    WHERE application_id = p_application_id;
    
    IF v_existing_offer_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offer already exists for this application';
    END IF;
    
    -- Create offer (DML - INSERT)
    INSERT INTO offers (
        application_id,
        offered_ctc,
        offered_role,
        job_location,
        joining_date,
        acceptance_deadline,
        status
    ) VALUES (
        p_application_id,
        p_offered_ctc,
        p_offered_role,
        p_job_location,
        p_joining_date,
        p_acceptance_deadline,
        'pending'
    );
    
    SET p_offer_id = LAST_INSERT_ID();
    
    -- Update application status to selected
    UPDATE applications
    SET status = 'selected', updated_at = NOW()
    WHERE application_id = p_application_id;
    
    SET p_message = 'Offer created successfully';
    
    COMMIT;
END$$

-- =============================================================================
-- PROCEDURE 4: sp_accept_offer (CRITICAL TRANSACTION)
-- =============================================================================
-- SYLLABUS: Complex Transaction, Multiple DML operations, SAVEPOINT
-- DEMONSTRATES: ACID properties, Consistency enforcement
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_accept_offer$$

CREATE PROCEDURE sp_accept_offer(
    IN p_offer_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    
    
    DECLARE v_application_id INT;
    DECLARE v_student_id INT;
    DECLARE v_company_id INT;
    DECLARE v_offer_status VARCHAR(20);
    DECLARE v_offered_ctc DECIMAL(10,2);
    DECLARE v_is_dream BOOLEAN;
    DECLARE v_is_already_placed BOOLEAN;
    
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    -- Step 1: Get offer details with lock
    SELECT 
        o.application_id, 
        o.status, 
        o.offered_ctc,
        a.student_id,
        a.company_id
    INTO 
        v_application_id, 
        v_offer_status, 
        v_offered_ctc,
        v_student_id,
        v_company_id
    FROM offers o
    JOIN applications a ON o.application_id = a.application_id
    WHERE o.offer_id = p_offer_id
    FOR UPDATE;
    
    -- Validate offer exists
    IF v_application_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offer not found';
    END IF;
    
    -- Validate offer status
    IF v_offer_status != 'pending' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offer already processed';
    END IF;
    
    -- Check if company is dream
    SELECT is_dream INTO v_is_dream
    FROM companies
    WHERE company_id = v_company_id;
    
    -- Check student placement status
    SELECT is_placed INTO v_is_already_placed
    FROM students
    WHERE student_id = v_student_id
    FOR UPDATE;
    
    -- SAVEPOINT before major changes (TCL - SAVEPOINT)
    SAVEPOINT before_acceptance;
    
    -- Step 2: Accept this offer
    UPDATE offers
    SET 
        status = 'accepted',
        accepted_at = NOW(),
        updated_at = NOW()
    WHERE offer_id = p_offer_id;
    
    -- Step 3: Update student placement status
    IF v_is_dream THEN
        UPDATE students
        SET 
            is_placed = TRUE,
            placement_type = 'dream',
            updated_at = NOW()
        WHERE student_id = v_student_id;
    ELSE
        UPDATE students
        SET 
            is_placed = TRUE,
            placement_type = 'regular',
            updated_at = NOW()
        WHERE student_id = v_student_id;
    END IF;
    
    -- Step 4: Decline all other pending offers for this student
    UPDATE offers o
    JOIN applications a ON o.application_id = a.application_id
    SET 
        o.status = 'declined',
        o.updated_at = NOW()
    WHERE 
        a.student_id = v_student_id 
        AND o.offer_id != p_offer_id
        AND o.status = 'pending';
    
    -- Step 5: Withdraw all other pending applications
    UPDATE applications
    SET 
        status = 'withdrawn',
        updated_at = NOW()
    WHERE 
        student_id = v_student_id
        AND status IN ('applied', 'in_progress')
        AND company_id != v_company_id;
    
    SET p_success = TRUE;
    SET p_message = 'Offer accepted successfully. All other applications withdrawn.';
    
    COMMIT;
    
END$$

-- =============================================================================
-- PROCEDURE 5: sp_decline_offer
-- =============================================================================
-- SYLLABUS: Simple transaction with validation
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_decline_offer$$

CREATE PROCEDURE sp_decline_offer(
    IN p_offer_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    
    
    DECLARE v_offer_status VARCHAR(20);
    
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    SELECT status INTO v_offer_status
    FROM offers
    WHERE offer_id = p_offer_id
    FOR UPDATE;
    
    IF v_offer_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offer not found';
    END IF;
    
    IF v_offer_status != 'pending' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Offer cannot be declined - already processed';
    END IF;
    
    UPDATE offers
    SET status = 'declined', updated_at = NOW()
    WHERE offer_id = p_offer_id;
    
    SET p_success = TRUE;
    SET p_message = 'Offer declined successfully';
    
    COMMIT;
END$$

-- =============================================================================
-- PROCEDURE 6: sp_withdraw_application
-- =============================================================================
-- SYLLABUS: DML UPDATE, Transaction
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_withdraw_application$$

CREATE PROCEDURE sp_withdraw_application(
    IN p_application_id INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    
    
    DECLARE v_current_status VARCHAR(20);
    DECLARE v_has_offer INT;
    
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    SELECT status INTO v_current_status
    FROM applications
    WHERE application_id = p_application_id
    FOR UPDATE;
    
    IF v_current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Application not found';
    END IF;
    
    IF v_current_status IN ('rejected', 'withdrawn') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Application already closed';
    END IF;
    
    -- Check if offer exists
    SELECT COUNT(*) INTO v_has_offer
    FROM offers
    WHERE application_id = p_application_id AND status = 'pending';
    
    IF v_has_offer > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot withdraw - pending offer exists. Decline offer first.';
    END IF;
    
    UPDATE applications
    SET status = 'withdrawn', updated_at = NOW()
    WHERE application_id = p_application_id;
    
    SET p_success = TRUE;
    SET p_message = 'Application withdrawn successfully';
    
    COMMIT;
END$$

-- =============================================================================
-- PROCEDURE 7: sp_get_eligible_companies (WITH CURSOR)
-- =============================================================================
-- SYLLABUS: CURSOR demonstration, Loop processing
-- DEMONSTRATES: DECLARE CURSOR, OPEN, FETCH, CLOSE
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_get_eligible_companies$$

CREATE PROCEDURE sp_get_eligible_companies(
    IN p_student_id INT
)
BEGIN
    -- Student variables
    DECLARE v_cgpa DECIMAL(4,2);
    DECLARE v_backlogs INT;
    DECLARE v_department VARCHAR(10);
    DECLARE v_is_placed BOOLEAN;
    
    -- Cursor variables
    DECLARE v_company_id INT;
    DECLARE v_company_name VARCHAR(100);
    DECLARE v_ctc DECIMAL(10,2);
    DECLARE v_is_dream BOOLEAN;
    DECLARE v_min_cgpa DECIMAL(4,2);
    DECLARE v_max_backlogs INT;
    DECLARE v_allowed_depts JSON;
    DECLARE v_visit_date DATE;
    DECLARE v_deadline DATETIME;
    DECLARE v_done INT DEFAULT FALSE;
    
    -- CURSOR declaration (SYLLABUS: CURSOR)
    DECLARE company_cursor CURSOR FOR
        SELECT 
            c.company_id,
            c.name,
            c.ctc_lpa,
            c.is_dream,
            c.visit_date,
            c.registration_deadline,
            e.min_cgpa,
            e.max_backlogs,
            e.allowed_departments
        FROM companies c
        JOIN eligibility_criteria e ON c.company_id = e.company_id
        WHERE c.status = 'upcoming'
        AND c.registration_deadline > NOW()
        ORDER BY c.visit_date;
    
    -- Handler for cursor end
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    -- Temporary table for results
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_eligible_companies (
        company_id INT,
        company_name VARCHAR(100),
        ctc_lpa DECIMAL(10,2),
        is_dream BOOLEAN,
        visit_date DATE,
        registration_deadline DATETIME,
        eligibility_status VARCHAR(50)
    );
    
    -- Clear temp table
    TRUNCATE TABLE temp_eligible_companies;
    
    -- Get student details
    SELECT cgpa, backlogs, department, is_placed
    INTO v_cgpa, v_backlogs, v_department, v_is_placed
    FROM students
    WHERE student_id = p_student_id;
    
    IF v_cgpa IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Student not found';
    END IF;
    
    -- OPEN cursor (SYLLABUS: OPEN CURSOR)
    OPEN company_cursor;
    
    -- LOOP through cursor (SYLLABUS: FETCH)
    read_loop: LOOP
        FETCH company_cursor INTO 
            v_company_id, v_company_name, v_ctc, v_is_dream, v_visit_date,
            v_deadline, v_min_cgpa, v_max_backlogs, v_allowed_depts;
        
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        
        -- Check eligibility criteria
        IF v_cgpa >= v_min_cgpa 
           AND v_backlogs <= v_max_backlogs
           AND JSON_CONTAINS(v_allowed_depts, CONCAT('"', v_department, '"')) THEN
            
            -- Check placement policy
            IF v_is_placed = FALSE OR v_is_dream = TRUE THEN
                -- Check if already applied
                IF NOT EXISTS (
                    SELECT 1 FROM applications 
                    WHERE student_id = p_student_id AND company_id = v_company_id
                ) THEN
                    -- Add to eligible list
                    INSERT INTO temp_eligible_companies VALUES (
                        v_company_id, v_company_name, v_ctc, v_is_dream,
                        v_visit_date, v_deadline, 'Eligible'
                    );
                ELSE
                    INSERT INTO temp_eligible_companies VALUES (
                        v_company_id, v_company_name, v_ctc, v_is_dream,
                        v_visit_date, v_deadline, 'Already Applied'
                    );
                END IF;
            ELSE
                INSERT INTO temp_eligible_companies VALUES (
                    v_company_id, v_company_name, v_ctc, v_is_dream,
                    v_visit_date, v_deadline, 'Not Eligible - Already Placed'
                );
            END IF;
        END IF;
        
    END LOOP;
    
    -- CLOSE cursor (SYLLABUS: CLOSE CURSOR)
    CLOSE company_cursor;
    
    -- Return results
    SELECT * FROM temp_eligible_companies
    ORDER BY visit_date, ctc_lpa DESC;
    
    -- Cleanup
    DROP TEMPORARY TABLE temp_eligible_companies;
    
END$$

-- =============================================================================
-- PROCEDURE 8: sp_process_round_shortlist (BULK PROCESSING WITH CURSOR)
-- =============================================================================
-- SYLLABUS: Cursor for bulk operations, Complex business logic
-- =============================================================================

DROP PROCEDURE IF EXISTS sp_process_round_shortlist$$

CREATE PROCEDURE sp_process_round_shortlist(
    IN p_round_id INT,
    IN p_min_score DECIMAL(5,2)
)
BEGIN
    DECLARE v_application_id INT;
    DECLARE v_score DECIMAL(5,2);
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_shortlisted_count INT DEFAULT 0;
    
    -- Cursor to fetch all results for this round
    DECLARE result_cursor CURSOR FOR
        SELECT application_id, score
        FROM round_results
        WHERE round_id = p_round_id 
        AND status = 'pending'
        AND score IS NOT NULL;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    DECLARE exit handler for SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;
    
    OPEN result_cursor;
    
    process_loop: LOOP
        FETCH result_cursor INTO v_application_id, v_score;
        
        IF v_done THEN
            LEAVE process_loop;
        END IF;
        
        -- Update based on score threshold
        IF v_score >= p_min_score THEN
            UPDATE round_results
            SET status = 'shortlisted', updated_at = NOW()
            WHERE round_id = p_round_id AND application_id = v_application_id;
            
            UPDATE applications
            SET status = 'in_progress', updated_at = NOW()
            WHERE application_id = v_application_id;
            
            SET v_shortlisted_count = v_shortlisted_count + 1;
        ELSE
            UPDATE round_results
            SET status = 'rejected', updated_at = NOW()
            WHERE round_id = p_round_id AND application_id = v_application_id;
        END IF;
        
    END LOOP;
    
    CLOSE result_cursor;
    
    COMMIT;
    
    -- Return summary
    SELECT 
        p_round_id AS round_id,
        v_shortlisted_count AS shortlisted_count,
        'Bulk processing completed' AS message;
    
END$$

DELIMITER ;

-- =============================================================================
-- PROCEDURES CREATED SUCCESSFULLY
-- =============================================================================
-- Total: 8 procedures demonstrating:
-- - Transactions (START, COMMIT, ROLLBACK, SAVEPOINT)
-- - Exception handling (DECLARE HANDLER, SIGNAL)
-- - Cursors (DECLARE, OPEN, FETCH, CLOSE, LOOP)
-- - Concurrency control (SELECT FOR UPDATE)
-- - Business logic encapsulation
-- =============================================================================
