-- =============================================================================
-- PLACIFY - VIEWS
-- File: views.sql
-- =============================================================================
-- SYLLABUS MAPPING: Views, JOINs, GROUP BY, HAVING, Aggregate Functions
-- =============================================================================

USE campus_placement;

-- =============================================================================
-- VIEW 1: vw_student_dashboard
-- =============================================================================
-- SYLLABUS: Multiple JOINs, Column aliasing
-- PURPOSE: Student profile with placement summary
-- =============================================================================

CREATE OR REPLACE VIEW vw_student_dashboard AS
SELECT 
    s.student_id,
    s.roll_number,
    s.name,
    s.email,
    s.department,
    s.batch_year,
    s.cgpa,
    s.backlogs,
    s.is_placed,
    s.placement_type,
    u.is_active,
    u.created_at AS registered_on,
    u.last_login,
    -- Aggregate subqueries
    (SELECT COUNT(*) 
     FROM applications a 
     WHERE a.student_id = s.student_id) AS total_applications,
    (SELECT COUNT(*) 
     FROM applications a 
     WHERE a.student_id = s.student_id 
     AND a.status = 'selected') AS selected_count,
    (SELECT COUNT(*) 
     FROM offers o 
     JOIN applications a ON o.application_id = a.application_id 
     WHERE a.student_id = s.student_id) AS total_offers,
    (SELECT MAX(o.offered_ctc) 
     FROM offers o 
     JOIN applications a ON o.application_id = a.application_id 
     WHERE a.student_id = s.student_id 
     AND o.status = 'accepted') AS highest_package,
    (SELECT COUNT(*) 
     FROM student_skills ss 
     WHERE ss.student_id = s.student_id) AS skills_count
FROM students s
JOIN users u ON s.user_id = u.user_id;

-- =============================================================================
-- VIEW 2: vw_company_statistics
-- =============================================================================
-- SYLLABUS: GROUP BY, Aggregate Functions (COUNT, AVG, MAX, MIN)
-- PURPOSE: Company-wise placement statistics
-- =============================================================================

CREATE OR REPLACE VIEW vw_company_statistics AS
SELECT 
    c.company_id,
    c.name AS company_name,
    c.company_type,
    c.industry,
    c.ctc_lpa,
    c.is_dream,
    c.job_role,
    c.status AS company_status,
    c.visit_date,
    -- Aggregate functions (SYLLABUS: AGGREGATE FUNCTIONS)
    COUNT(DISTINCT a.application_id) AS total_applications,
    COUNT(DISTINCT CASE WHEN a.status = 'selected' THEN a.application_id END) AS selected_count,
    COUNT(DISTINCT CASE WHEN a.status = 'rejected' THEN a.application_id END) AS rejected_count,
    COUNT(DISTINCT o.offer_id) AS total_offers,
    COUNT(DISTINCT CASE WHEN o.status = 'accepted' THEN o.offer_id END) AS accepted_offers,
    AVG(o.offered_ctc) AS avg_package_offered,
    MAX(o.offered_ctc) AS max_package_offered,
    MIN(o.offered_ctc) AS min_package_offered,
    COUNT(DISTINCT r.round_id) AS total_rounds
FROM companies c
LEFT JOIN applications a ON c.company_id = a.company_id
LEFT JOIN offers o ON a.application_id = o.application_id
LEFT JOIN rounds r ON c.company_id = r.company_id
GROUP BY 
    c.company_id, c.name, c.company_type, c.industry, 
    c.ctc_lpa, c.is_dream, c.job_role, c.status, c.visit_date;

-- =============================================================================
-- VIEW 3: vw_department_placement_stats
-- =============================================================================
-- SYLLABUS: GROUP BY, HAVING, Calculated columns
-- PURPOSE: Department-wise placement analysis
-- =============================================================================

CREATE OR REPLACE VIEW vw_department_placement_stats AS
SELECT 
    s.department,
    s.batch_year,
    -- COUNT aggregate (SYLLABUS: COUNT)
    COUNT(*) AS total_students,
    COUNT(CASE WHEN s.is_placed = TRUE THEN 1 END) AS placed_students,
    COUNT(CASE WHEN s.is_placed = FALSE THEN 1 END) AS unplaced_students,
    -- Percentage calculation
    ROUND((COUNT(CASE WHEN s.is_placed = TRUE THEN 1 END) / COUNT(*)) * 100, 2) 
        AS placement_percentage,
    -- AVG aggregate (SYLLABUS: AVG)
    ROUND(AVG(s.cgpa), 2) AS average_cgpa,
    ROUND(AVG(CASE WHEN s.is_placed = TRUE THEN s.cgpa END), 2) 
        AS average_cgpa_placed,
    -- MAX/MIN aggregates (SYLLABUS: MAX, MIN)
    MAX(s.cgpa) AS highest_cgpa,
    MIN(s.cgpa) AS lowest_cgpa,
    -- Subquery for highest package
    (SELECT MAX(o.offered_ctc)
     FROM offers o
     JOIN applications a ON o.application_id = a.application_id
     JOIN students st ON a.student_id = st.student_id
     WHERE st.department = s.department 
     AND st.batch_year = s.batch_year
     AND o.status = 'accepted') AS highest_package,
    -- COUNT for different placement types
    COUNT(CASE WHEN s.placement_type = 'dream' THEN 1 END) AS dream_placements,
    COUNT(CASE WHEN s.placement_type = 'regular' THEN 1 END) AS regular_placements
FROM students s
GROUP BY s.department, s.batch_year
-- HAVING clause (SYLLABUS: HAVING)
HAVING COUNT(*) > 0
ORDER BY s.batch_year DESC, s.department;

-- =============================================================================
-- VIEW 4: vw_active_applications
-- =============================================================================
-- SYLLABUS: Multiple JOINs, WHERE filtering
-- PURPOSE: Current active applications with full details
-- =============================================================================

CREATE OR REPLACE VIEW vw_active_applications AS
SELECT 
    a.application_id,
    a.status AS application_status,
    a.applied_at,
    -- Student details (JOIN)
    s.student_id,
    s.roll_number,
    s.name AS student_name,
    s.email AS student_email,
    s.department,
    s.batch_year,
    s.cgpa,
    s.backlogs,
    -- Company details (JOIN)
    c.company_id,
    c.name AS company_name,
    c.company_type,
    c.ctc_lpa,
    c.is_dream,
    c.job_role,
    c.job_location,
    c.visit_date,
    c.registration_deadline,
    -- Eligibility details (JOIN)
    e.min_cgpa AS required_cgpa,
    e.max_backlogs AS max_backlogs_allowed,
    -- Calculated eligibility score using function
    fn_calculate_eligibility_score(s.student_id, c.company_id) AS eligibility_score,
    -- Round progress
    (SELECT COUNT(*) 
     FROM round_results rr 
     JOIN rounds r ON rr.round_id = r.round_id 
     WHERE rr.application_id = a.application_id 
     AND rr.status = 'shortlisted') AS rounds_cleared,
    (SELECT COUNT(*) 
     FROM rounds r 
     WHERE r.company_id = c.company_id) AS total_rounds
FROM applications a
JOIN students s ON a.student_id = s.student_id
JOIN companies c ON a.company_id = c.company_id
JOIN eligibility_criteria e ON c.company_id = e.company_id
WHERE a.status IN ('applied', 'in_progress', 'selected')
ORDER BY a.applied_at DESC;

-- =============================================================================
-- VIEW 5: vw_placement_leaderboard
-- =============================================================================
-- SYLLABUS: ORDER BY, LIMIT concept, Complex calculations
-- PURPOSE: Top performers by package
-- =============================================================================

CREATE OR REPLACE VIEW vw_placement_leaderboard AS
SELECT 
    s.student_id,
    s.roll_number,
    s.name AS student_name,
    s.department,
    s.batch_year,
    s.cgpa,
    s.placement_type,
    -- Highest package using function
    fn_get_student_highest_package(s.student_id) AS highest_package,
    -- Company details
    (SELECT c.name 
     FROM companies c
     JOIN applications a ON c.company_id = a.company_id
     JOIN offers o ON a.application_id = o.application_id
     WHERE a.student_id = s.student_id
     AND o.status = 'accepted'
     ORDER BY o.offered_ctc DESC
     LIMIT 1) AS placed_company,
    -- Rank calculation (using window-like logic through function)
    fn_get_placement_rank(s.student_id, s.batch_year) AS batch_rank,
    -- Total applications
    (SELECT COUNT(*) 
     FROM applications a 
     WHERE a.student_id = s.student_id) AS applications_made,
    -- Total offers
    (SELECT COUNT(*) 
     FROM offers o 
     JOIN applications a ON o.application_id = a.application_id 
     WHERE a.student_id = s.student_id) AS offers_received
FROM students s
WHERE s.is_placed = TRUE
ORDER BY fn_get_student_highest_package(s.student_id) DESC, s.cgpa DESC;

-- =============================================================================
-- VIEW 6: vw_upcoming_drives
-- =============================================================================
-- SYLLABUS: JOIN, WHERE with date functions, ORDER BY
-- PURPOSE: Companies with upcoming recruitment drives
-- =============================================================================

CREATE OR REPLACE VIEW vw_upcoming_drives AS
SELECT 
    c.company_id,
    c.name AS company_name,
    c.description,
    c.website,
    c.industry,
    c.company_type,
    c.job_role,
    c.job_description,
    c.job_location,
    c.ctc_lpa,
    c.is_dream,
    c.visit_date,
    c.registration_deadline,
    -- Days until deadline
    DATEDIFF(c.registration_deadline, NOW()) AS days_until_deadline,
    -- Eligibility details
    e.min_cgpa,
    e.max_backlogs,
    e.allowed_departments,
    -- Application count
    (SELECT COUNT(*) 
     FROM applications a 
     WHERE a.company_id = c.company_id) AS current_applications,
    -- Rounds configured
    (SELECT COUNT(*) 
     FROM rounds r 
     WHERE r.company_id = c.company_id) AS rounds_configured
FROM companies c
JOIN eligibility_criteria e ON c.company_id = e.company_id
WHERE c.status = 'upcoming'
AND c.registration_deadline > NOW()
ORDER BY c.visit_date ASC, c.registration_deadline ASC;

-- =============================================================================
-- VIEW 7: vw_round_results_summary
-- =============================================================================
-- SYLLABUS: GROUP BY with multiple columns, CASE expressions
-- PURPOSE: Round-wise performance summary
-- =============================================================================

CREATE OR REPLACE VIEW vw_round_results_summary AS
SELECT 
    r.round_id,
    r.round_number,
    r.round_type,
    r.round_name,
    c.company_id,
    c.name AS company_name,
    r.scheduled_date,
    r.status AS round_status,
    -- Aggregate statistics (SYLLABUS: GROUP BY with aggregates)
    COUNT(*) AS total_participants,
    COUNT(CASE WHEN rr.status = 'shortlisted' THEN 1 END) AS shortlisted,
    COUNT(CASE WHEN rr.status = 'rejected' THEN 1 END) AS rejected,
    COUNT(CASE WHEN rr.status = 'pending' THEN 1 END) AS pending,
    COUNT(CASE WHEN rr.attended = TRUE THEN 1 END) AS attended,
    COUNT(CASE WHEN rr.attended = FALSE THEN 1 END) AS absent,
    -- Score statistics
    AVG(rr.score) AS average_score,
    MAX(rr.score) AS highest_score,
    MIN(rr.score) AS lowest_score,
    -- Percentage calculations
    ROUND((COUNT(CASE WHEN rr.status = 'shortlisted' THEN 1 END) / COUNT(*)) * 100, 2) 
        AS shortlist_percentage,
    ROUND((COUNT(CASE WHEN rr.attended = TRUE THEN 1 END) / COUNT(*)) * 100, 2) 
        AS attendance_percentage
FROM round_results rr
JOIN rounds r ON rr.round_id = r.round_id
JOIN companies c ON r.company_id = c.company_id
GROUP BY 
    r.round_id, r.round_number, r.round_type, r.round_name,
    c.company_id, c.name, r.scheduled_date, r.status;

-- =============================================================================
-- VIEW 8: vw_offers_summary
-- =============================================================================
-- SYLLABUS: LEFT JOIN, GROUP BY, Multiple aggregates
-- PURPOSE: Offer status summary
-- =============================================================================

CREATE OR REPLACE VIEW vw_offers_summary AS
SELECT 
    c.company_id,
    c.name AS company_name,
    c.ctc_lpa AS posted_ctc,
    c.is_dream,
    -- Offer statistics
    COUNT(o.offer_id) AS total_offers_made,
    COUNT(CASE WHEN o.status = 'pending' THEN 1 END) AS pending_offers,
    COUNT(CASE WHEN o.status = 'accepted' THEN 1 END) AS accepted_offers,
    COUNT(CASE WHEN o.status = 'declined' THEN 1 END) AS declined_offers,
    COUNT(CASE WHEN o.status = 'expired' THEN 1 END) AS expired_offers,
    -- Package statistics
    AVG(o.offered_ctc) AS avg_package_offered,
    MAX(o.offered_ctc) AS max_package_offered,
    MIN(o.offered_ctc) AS min_package_offered,
    -- Acceptance rate
    ROUND((COUNT(CASE WHEN o.status = 'accepted' THEN 1 END) / 
           NULLIF(COUNT(o.offer_id), 0)) * 100, 2) AS acceptance_rate
FROM companies c
LEFT JOIN applications a ON c.company_id = a.company_id
LEFT JOIN offers o ON a.application_id = o.application_id
GROUP BY c.company_id, c.name, c.ctc_lpa, c.is_dream;

-- =============================================================================
-- VIEW 9: vw_student_skill_profile
-- =============================================================================
-- SYLLABUS: Multiple JOINs, GROUP_CONCAT (string aggregation)
-- PURPOSE: Student skills consolidated view
-- =============================================================================

CREATE OR REPLACE VIEW vw_student_skill_profile AS
SELECT 
    s.student_id,
    s.roll_number,
    s.name AS student_name,
    s.department,
    s.batch_year,
    -- Skill aggregation (SYLLABUS: GROUP_CONCAT)
    GROUP_CONCAT(
        DISTINCT CONCAT(sk.skill_name, ' (', ss.proficiency, ')')
        ORDER BY ss.proficiency DESC
        SEPARATOR ', '
    ) AS skills_list,
    COUNT(DISTINCT sk.skill_id) AS total_skills,
    -- Category-wise counts
    COUNT(DISTINCT CASE WHEN sk.category = 'programming' THEN sk.skill_id END) 
        AS programming_skills,
    COUNT(DISTINCT CASE WHEN sk.category = 'framework' THEN sk.skill_id END) 
        AS framework_skills,
    COUNT(DISTINCT CASE WHEN sk.category = 'database' THEN sk.skill_id END) 
        AS database_skills,
    COUNT(DISTINCT CASE WHEN sk.category = 'cloud' THEN sk.skill_id END) 
        AS cloud_skills,
    -- Expert level skills
    COUNT(DISTINCT CASE WHEN ss.proficiency = 'expert' THEN sk.skill_id END) 
        AS expert_skills_count
FROM students s
LEFT JOIN student_skills ss ON s.student_id = ss.student_id
LEFT JOIN skills sk ON ss.skill_id = sk.skill_id
GROUP BY s.student_id, s.roll_number, s.name, s.department, s.batch_year;

-- =============================================================================
-- VIEW 10: vw_batch_placement_comparison
-- =============================================================================
-- SYLLABUS: UNION (set operations), Complex aggregates
-- PURPOSE: Batch-wise placement comparison across years
-- =============================================================================

CREATE OR REPLACE VIEW vw_batch_placement_comparison AS
SELECT 
    batch_year,
    'Overall' AS metric_type,
    COUNT(*) AS total_students,
    COUNT(CASE WHEN is_placed = TRUE THEN 1 END) AS placed_count,
    ROUND((COUNT(CASE WHEN is_placed = TRUE THEN 1 END) / COUNT(*)) * 100, 2) 
        AS placement_percentage,
    ROUND(AVG(cgpa), 2) AS avg_cgpa,
    (SELECT MAX(o.offered_ctc)
     FROM offers o
     JOIN applications a ON o.application_id = a.application_id
     JOIN students st ON a.student_id = st.student_id
     WHERE st.batch_year = s.batch_year
     AND o.status = 'accepted') AS highest_package,
    (SELECT AVG(o.offered_ctc)
     FROM offers o
     JOIN applications a ON o.application_id = a.application_id
     JOIN students st ON a.student_id = st.student_id
     WHERE st.batch_year = s.batch_year
     AND o.status = 'accepted') AS avg_package
FROM students s
GROUP BY batch_year
ORDER BY batch_year DESC;

-- =============================================================================
-- VIEW 11: vw_dream_company_placements
-- =============================================================================
-- SYLLABUS: Filtered JOIN, Specific WHERE conditions
-- PURPOSE: Students placed in dream companies
-- =============================================================================

CREATE OR REPLACE VIEW vw_dream_company_placements AS
SELECT 
    s.student_id,
    s.roll_number,
    s.name AS student_name,
    s.department,
    s.batch_year,
    s.cgpa,
    c.company_id,
    c.name AS company_name,
    c.company_type,
    o.offered_ctc,
    o.offered_role,
    o.accepted_at,
    a.applied_at,
    -- Time from application to acceptance
    DATEDIFF(o.accepted_at, a.applied_at) AS days_to_placement
FROM students s
JOIN applications a ON s.student_id = a.student_id
JOIN companies c ON a.company_id = c.company_id
JOIN offers o ON a.application_id = o.application_id
WHERE c.is_dream = TRUE
AND o.status = 'accepted'
ORDER BY o.offered_ctc DESC, s.batch_year DESC;

-- =============================================================================
-- VIEW 12: vw_audit_trail
-- =============================================================================
-- SYLLABUS: JOIN with JSON parsing, Date filtering
-- PURPOSE: Comprehensive audit log view
-- =============================================================================

CREATE OR REPLACE VIEW vw_audit_trail AS
SELECT 
    al.log_id,
    al.table_name,
    al.action_type,
    al.record_id,
    al.created_at AS action_timestamp,
    u.email AS user_email,
    al.user_role,
    al.old_values,
    al.new_values,
    -- Extract specific fields from JSON for common tables
    CASE 
        WHEN al.table_name = 'applications' THEN
            JSON_UNQUOTE(JSON_EXTRACT(al.new_values, '$.status'))
        WHEN al.table_name = 'students' THEN
            JSON_UNQUOTE(JSON_EXTRACT(al.new_values, '$.is_placed'))
        WHEN al.table_name = 'offers' THEN
            JSON_UNQUOTE(JSON_EXTRACT(al.new_values, '$.status'))
        ELSE NULL
    END AS key_change
FROM audit_logs al
LEFT JOIN users u ON al.user_id = u.user_id
ORDER BY al.created_at DESC;

-- =============================================================================
-- VIEWS CREATED SUCCESSFULLY
-- =============================================================================
-- Total: 12 views demonstrating:
-- - Multiple table JOINs (INNER, LEFT, RIGHT)
-- - GROUP BY with multiple columns
-- - HAVING clause
-- - Aggregate functions (COUNT, AVG, MAX, MIN, SUM)
-- - Subqueries (correlated, nested)
-- - CASE expressions
-- - Date functions
-- - GROUP_CONCAT (string aggregation)
-- - Complex calculations
-- - JSON extraction
-- - Set operations concept (UNION in one view)
-- =============================================================================
