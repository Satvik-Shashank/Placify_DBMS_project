-- =============================================================================
-- PLACIFY - STORED FUNCTIONS
-- File: functions.sql
-- =============================================================================
-- SYLLABUS MAPPING: Functions, Subqueries, Aggregate Functions
-- =============================================================================

USE campus_placement;

DELIMITER $$

-- =============================================================================
-- FUNCTION 1: fn_calculate_eligibility_score
-- =============================================================================
-- SYLLABUS: Scalar function, Business logic calculation
-- DEMONSTRATES: Function return value, Mathematical operations
-- =============================================================================

DROP FUNCTION IF EXISTS fn_calculate_eligibility_score$$

CREATE FUNCTION fn_calculate_eligibility_score(
    p_student_id INT,
    p_company_id INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_score DECIMAL(5,2) DEFAULT 0;
    DECLARE v_cgpa DECIMAL(4,2);
    DECLARE v_backlogs INT;
    DECLARE v_min_cgpa DECIMAL(4,2);
    DECLARE v_max_backlogs INT;
    DECLARE v_cgpa_score DECIMAL(5,2);
    DECLARE v_backlog_penalty DECIMAL(5,2);
    
    -- Get student details (SUBQUERY concept)
    SELECT cgpa, backlogs
    INTO v_cgpa, v_backlogs
    FROM students
    WHERE student_id = p_student_id;
    
    -- Get company requirements
    SELECT min_cgpa, max_backlogs
    INTO v_min_cgpa, v_max_backlogs
    FROM eligibility_criteria
    WHERE company_id = p_company_id;
    
    -- Return 0 if not eligible
    IF v_cgpa < v_min_cgpa OR v_backlogs > v_max_backlogs THEN
        RETURN 0.00;
    END IF;
    
    -- Calculate CGPA score (out of 70 points)
    -- Formula: (student_cgpa / 10) * 70
    SET v_cgpa_score = (v_cgpa / 10.0) * 70.0;
    
    -- Calculate backlog penalty (out of 30 points)
    -- Formula: max(0, 30 - (backlogs * 10))
    SET v_backlog_penalty = GREATEST(0, 30 - (v_backlogs * 10));
    
    -- Total score
    SET v_score = v_cgpa_score + v_backlog_penalty;
    
    RETURN v_score;
END$$

-- =============================================================================
-- FUNCTION 2: fn_get_student_highest_package
-- =============================================================================
-- SYLLABUS: Function with SUBQUERY, MAX aggregate
-- DEMONSTRATES: Aggregate function within function
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_student_highest_package$$

CREATE FUNCTION fn_get_student_highest_package(
    p_student_id INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_highest_package DECIMAL(10,2);
    
    -- SUBQUERY with JOIN and MAX (AGGREGATE FUNCTION)
    SELECT MAX(o.offered_ctc)
    INTO v_highest_package
    FROM offers o
    JOIN applications a ON o.application_id = a.application_id
    WHERE a.student_id = p_student_id
    AND o.status = 'accepted';
    
    -- Return 0 if no accepted offers
    RETURN IFNULL(v_highest_package, 0.00);
END$$

-- =============================================================================
-- FUNCTION 3: fn_check_dream_eligibility
-- =============================================================================
-- SYLLABUS: Boolean function, Complex logic, EXISTS subquery
-- DEMONSTRATES: EXISTS, Correlated subquery
-- =============================================================================

DROP FUNCTION IF EXISTS fn_check_dream_eligibility$$

CREATE FUNCTION fn_check_dream_eligibility(
    p_student_id INT,
    p_company_id INT
)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_is_placed BOOLEAN;
    DECLARE v_is_dream BOOLEAN;
    DECLARE v_current_package DECIMAL(10,2);
    DECLARE v_new_package DECIMAL(10,2);
    DECLARE v_dream_min_ctc DECIMAL(10,2);
    
    -- Get student placement status
    SELECT is_placed INTO v_is_placed
    FROM students
    WHERE student_id = p_student_id;
    
    -- If not placed, eligible for all companies
    IF v_is_placed = FALSE THEN
        RETURN TRUE;
    END IF;
    
    -- Get company dream status and CTC
    SELECT is_dream, ctc_lpa
    INTO v_is_dream, v_new_package
    FROM companies
    WHERE company_id = p_company_id;
    
    -- If company is not dream, student cannot apply
    IF v_is_dream = FALSE THEN
        RETURN FALSE;
    END IF;
    
    -- Get student's current package
    SET v_current_package = fn_get_student_highest_package(p_student_id);
    
    -- Get dream minimum CTC from eligibility criteria
    SELECT dream_min_ctc
    INTO v_dream_min_ctc
    FROM eligibility_criteria
    WHERE company_id = p_company_id;
    
    -- Check if new package is higher
    IF v_new_package > v_current_package THEN
        -- Check if it meets dream minimum threshold
        IF v_dream_min_ctc IS NULL OR v_new_package >= v_dream_min_ctc THEN
            RETURN TRUE;
        END IF;
    END IF;
    
    RETURN FALSE;
END$$

-- =============================================================================
-- FUNCTION 4: fn_get_department_placement_percentage
-- =============================================================================
-- SYLLABUS: Aggregate functions (COUNT), GROUP BY concept in function
-- DEMONSTRATES: Division, DECIMAL arithmetic, Aggregate calculation
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_department_placement_percentage$$

CREATE FUNCTION fn_get_department_placement_percentage(
    p_department VARCHAR(10),
    p_batch_year INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total_students INT;
    DECLARE v_placed_students INT;
    DECLARE v_percentage DECIMAL(5,2);
    
    -- COUNT total students (AGGREGATE FUNCTION)
    SELECT COUNT(*)
    INTO v_total_students
    FROM students
    WHERE department = p_department
    AND batch_year = p_batch_year;
    
    -- Avoid division by zero
    IF v_total_students = 0 THEN
        RETURN 0.00;
    END IF;
    
    -- COUNT placed students (WHERE clause filtering)
    SELECT COUNT(*)
    INTO v_placed_students
    FROM students
    WHERE department = p_department
    AND batch_year = p_batch_year
    AND is_placed = TRUE;
    
    -- Calculate percentage
    SET v_percentage = (v_placed_students / v_total_students) * 100.0;
    
    RETURN v_percentage;
END$$

-- =============================================================================
-- FUNCTION 5: fn_get_round_completion_percentage
-- =============================================================================
-- SYLLABUS: Function with multiple subqueries, CASE expression
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_round_completion_percentage$$

CREATE FUNCTION fn_get_round_completion_percentage(
    p_round_id INT
)
RETURNS DECIMAL(5,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total_applications INT;
    DECLARE v_processed_results INT;
    DECLARE v_percentage DECIMAL(5,2);
    
    -- Count total applications for this company/round
    -- SUBQUERY with JOIN
    SELECT COUNT(DISTINCT a.application_id)
    INTO v_total_applications
    FROM applications a
    JOIN rounds r ON a.company_id = r.company_id
    WHERE r.round_id = p_round_id
    AND a.status NOT IN ('withdrawn', 'rejected');
    
    IF v_total_applications = 0 THEN
        RETURN 0.00;
    END IF;
    
    -- Count processed results (status != pending)
    SELECT COUNT(*)
    INTO v_processed_results
    FROM round_results
    WHERE round_id = p_round_id
    AND status != 'pending';
    
    -- Calculate percentage
    SET v_percentage = (v_processed_results / v_total_applications) * 100.0;
    
    RETURN LEAST(v_percentage, 100.00);
END$$

-- =============================================================================
-- FUNCTION 6: fn_get_company_avg_package
-- =============================================================================
-- SYLLABUS: AVG aggregate function, JOIN in function
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_company_avg_package$$

CREATE FUNCTION fn_get_company_avg_package(
    p_company_id INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_avg_package DECIMAL(10,2);
    
    -- AVG aggregate with JOIN (SYLLABUS: AGGREGATE FUNCTION)
    SELECT AVG(o.offered_ctc)
    INTO v_avg_package
    FROM offers o
    JOIN applications a ON o.application_id = a.application_id
    WHERE a.company_id = p_company_id
    AND o.status = 'accepted';
    
    RETURN IFNULL(v_avg_package, 0.00);
END$$

-- =============================================================================
-- FUNCTION 7: fn_count_active_applications
-- =============================================================================
-- SYLLABUS: COUNT with WHERE conditions, IN operator
-- =============================================================================

DROP FUNCTION IF EXISTS fn_count_active_applications$$

CREATE FUNCTION fn_count_active_applications(
    p_student_id INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    
    -- COUNT with IN operator (SYLLABUS: IN operator)
    SELECT COUNT(*)
    INTO v_count
    FROM applications
    WHERE student_id = p_student_id
    AND status IN ('applied', 'in_progress', 'selected');
    
    RETURN v_count;
END$$

-- =============================================================================
-- FUNCTION 8: fn_get_placement_rank
-- =============================================================================
-- SYLLABUS: Correlated subquery, COUNT for ranking
-- DEMONSTRATES: Self-join concept through subquery
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_placement_rank$$

CREATE FUNCTION fn_get_placement_rank(
    p_student_id INT,
    p_batch_year INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_student_package DECIMAL(10,2);
    DECLARE v_rank INT;
    
    -- Get student's package
    SET v_student_package = fn_get_student_highest_package(p_student_id);
    
    IF v_student_package = 0 THEN
        RETURN 0;
    END IF;
    
    -- CORRELATED SUBQUERY for ranking (SYLLABUS: CORRELATED SUBQUERY)
    -- Count how many students have higher package
    SELECT COUNT(*) + 1
    INTO v_rank
    FROM students s
    WHERE s.batch_year = p_batch_year
    AND s.is_placed = TRUE
    AND fn_get_student_highest_package(s.student_id) > v_student_package;
    
    RETURN v_rank;
END$$

-- =============================================================================
-- FUNCTION 9: fn_check_application_exists
-- =============================================================================
-- SYLLABUS: Boolean function, EXISTS operator
-- DEMONSTRATES: EXISTS for existence check
-- =============================================================================

DROP FUNCTION IF EXISTS fn_check_application_exists$$

CREATE FUNCTION fn_check_application_exists(
    p_student_id INT,
    p_company_id INT
)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_exists BOOLEAN;
    
    -- EXISTS operator (SYLLABUS: EXISTS)
    SELECT EXISTS(
        SELECT 1 
        FROM applications 
        WHERE student_id = p_student_id 
        AND company_id = p_company_id
    ) INTO v_exists;
    
    RETURN v_exists;
END$$

-- =============================================================================
-- FUNCTION 10: fn_get_highest_package_in_batch
-- =============================================================================
-- SYLLABUS: MAX with subquery, NESTED QUERY
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_highest_package_in_batch$$

CREATE FUNCTION fn_get_highest_package_in_batch(
    p_batch_year INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_max_package DECIMAL(10,2);
    
    -- NESTED QUERY (SYLLABUS: NESTED QUERY)
    -- Inner query gets all packages, outer gets MAX
    SELECT MAX(package)
    INTO v_max_package
    FROM (
        SELECT o.offered_ctc AS package
        FROM offers o
        JOIN applications a ON o.application_id = a.application_id
        JOIN students s ON a.student_id = s.student_id
        WHERE s.batch_year = p_batch_year
        AND o.status = 'accepted'
    ) AS batch_packages;
    
    RETURN IFNULL(v_max_package, 0.00);
END$$

-- =============================================================================
-- FUNCTION 11: fn_get_total_offers_count
-- =============================================================================
-- SYLLABUS: Simple COUNT aggregate
-- =============================================================================

DROP FUNCTION IF EXISTS fn_get_total_offers_count$$

CREATE FUNCTION fn_get_total_offers_count(
    p_company_id INT
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    
    SELECT COUNT(*)
    INTO v_count
    FROM offers o
    JOIN applications a ON o.application_id = a.application_id
    WHERE a.company_id = p_company_id;
    
    RETURN v_count;
END$$

-- =============================================================================
-- FUNCTION 12: fn_check_all_rounds_cleared
-- =============================================================================
-- SYLLABUS: NOT EXISTS, ALL concept simulation
-- DEMONSTRATES: Negative logic with NOT EXISTS
-- =============================================================================

DROP FUNCTION IF EXISTS fn_check_all_rounds_cleared$$

CREATE FUNCTION fn_check_all_rounds_cleared(
    p_application_id INT
)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_company_id INT;
    DECLARE v_all_cleared BOOLEAN;
    
    -- Get company from application
    SELECT company_id INTO v_company_id
    FROM applications
    WHERE application_id = p_application_id;
    
    -- Check if there exists any round where student didn't get shortlisted
    -- NOT EXISTS pattern (SYLLABUS: NOT EXISTS)
    SELECT NOT EXISTS(
        SELECT 1
        FROM rounds r
        WHERE r.company_id = v_company_id
        AND NOT EXISTS(
            SELECT 1
            FROM round_results rr
            WHERE rr.round_id = r.round_id
            AND rr.application_id = p_application_id
            AND rr.status = 'shortlisted'
        )
    ) INTO v_all_cleared;
    
    RETURN v_all_cleared;
END$$

DELIMITER ;

-- =============================================================================
-- FUNCTIONS CREATED SUCCESSFULLY
-- =============================================================================
-- Total: 12 functions demonstrating:
-- - Scalar functions with calculations
-- - Aggregate functions (COUNT, AVG, MAX)
-- - Subqueries (simple, correlated, nested)
-- - EXISTS and NOT EXISTS
-- - IN operator
-- - Business logic encapsulation
-- - Reusable calculation logic
-- =============================================================================
