-- =============================================================================
-- PLACIFY — SUPABASE SEED DATA (PostgreSQL)
-- Run FIFTH (LAST) in Supabase SQL Editor
-- =============================================================================

-- Skills master list
INSERT INTO skills (skill_name, category) VALUES
('Python', 'programming'), ('Java', 'programming'), ('C++', 'programming'),
('JavaScript', 'programming'), ('SQL', 'database'), ('MySQL', 'database'),
('PostgreSQL', 'database'), ('MongoDB', 'database'), ('React', 'framework'),
('Node.js', 'framework'), ('Flask', 'framework'), ('Django', 'framework'),
('AWS', 'cloud'), ('Docker', 'cloud'), ('Git', 'other'), ('Linux', 'other'),
('Communication', 'soft_skill'), ('Leadership', 'soft_skill'), ('Problem Solving', 'soft_skill')
ON CONFLICT (skill_name) DO NOTHING;

-- Companies
INSERT INTO companies (name, description, website, industry, company_type, job_role, job_description, job_location, ctc_lpa, is_dream, visit_date, registration_deadline, status) VALUES
('Google India', 'Software Engineering role — full-stack development on core products.', 'https://careers.google.com', 'Technology', 'mnc', 'Software Engineer', 'Design, develop and deploy large-scale distributed systems.', 'Bengaluru', 24.00, TRUE, CURRENT_DATE + INTERVAL '10 days', NOW() + INTERVAL '7 days', 'upcoming'),
('Infosys', 'Systems Engineer — enterprise software development.', 'https://www.infosys.com', 'Technology', 'service', 'Systems Engineer', 'Work on enterprise Java/.NET projects for global clients.', 'Pune', 3.60, FALSE, CURRENT_DATE + INTERVAL '5 days', NOW() + INTERVAL '3 days', 'upcoming'),
('Tata Consultancy Services', 'TCS NQT — National Qualifier Test for multiple roles.', 'https://www.tcs.com', 'Technology', 'service', 'Assistant System Engineer', 'Development and maintenance of client applications.', 'Chennai', 3.36, FALSE, CURRENT_DATE + INTERVAL '15 days', NOW() + INTERVAL '12 days', 'upcoming'),
('Amazon', 'SDE-1 — Work on AWS and core Amazon products.', 'https://amazon.jobs', 'Technology', 'mnc', 'Software Development Engineer', 'Build highly available, scalable services.', 'Hyderabad', 26.00, TRUE, CURRENT_DATE + INTERVAL '20 days', NOW() + INTERVAL '17 days', 'upcoming'),
('BHEL', 'Engineer Trainee — Power generation projects.', 'https://www.bhel.com', 'Manufacturing', 'psu', 'Engineer Trainee', 'Design and maintenance of power plant equipment.', 'Multiple', 6.50, FALSE, CURRENT_DATE + INTERVAL '8 days', NOW() + INTERVAL '5 days', 'upcoming'),
('Microsoft', 'Software Engineer — Azure and core platform.', 'https://careers.microsoft.com', 'Technology', 'mnc', 'Software Engineer', 'Build cloud services and developer tools.', 'Bengaluru', 44.00, TRUE, CURRENT_DATE + INTERVAL '30 days', NOW() + INTERVAL '20 days', 'upcoming');

-- Eligibility criteria (by company name lookup)
INSERT INTO eligibility_criteria (company_id, min_cgpa, max_backlogs, allowed_departments, min_batch_year, max_batch_year)
SELECT company_id,
    CASE name WHEN 'Google India' THEN 8.0 WHEN 'Amazon' THEN 7.5 WHEN 'Microsoft' THEN 8.5 WHEN 'BHEL' THEN 6.0 ELSE 6.0 END,
    CASE name WHEN 'Google India' THEN 0 WHEN 'Amazon' THEN 0 WHEN 'Microsoft' THEN 0 ELSE 2 END,
    CASE name WHEN 'BHEL' THEN '["ME","EEE","CE"]'::JSONB WHEN 'Google India' THEN '["CSE","IT","ECE"]'::JSONB WHEN 'Amazon' THEN '["CSE","IT","ECE"]'::JSONB WHEN 'Microsoft' THEN '["CSE","IT"]'::JSONB ELSE '["CSE","ECE","IT","ME","CE","EEE"]'::JSONB END,
    2025, 2025
FROM companies
ON CONFLICT (company_id) DO NOTHING;

-- =============================================================================
-- DEMO USER ACCOUNTS
-- NOTE: Passwords below are hashed using werkzeug's pbkdf2:sha256.
-- You MUST generate fresh hashes using your Python environment:
--
--   python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('admin123'))"
--   python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('student123'))"
--   python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('microsoft123'))"
--
-- Then replace the placeholder hashes below with the real output.
-- =============================================================================

-- Admin user (password: admin123)
INSERT INTO users (email, password_hash, role) VALUES
('admin@placify.com', 'scrypt:32768:8:1$dpfRBtvueQnTutzf$05327d09f12512b1ca0727a7251573bedd4ab6d7e5710ab20dddaf175a4733178e9de562e78aa1b4aa6a5447333f28d9ceb229aef84169e5adaca1a0092d5eeb', 'admin')
ON CONFLICT (email) DO NOTHING;

-- Student users (password: student123 for all)
INSERT INTO users (email, password_hash, role) VALUES
('student@placify.com', 'scrypt:32768:8:1$6tA52IC70zvhwOuN$cf5e16c24e1b2b9c080992466f10413ce66c6c96dbff24225aced7bbef256fa15bfd4d6951f209080b25741c2df84abc6ef0507dc74687b6eb96409c8be1d15a', 'student'),
('cs_arjun@placify.com', 'scrypt:32768:8:1$6tA52IC70zvhwOuN$cf5e16c24e1b2b9c080992466f10413ce66c6c96dbff24225aced7bbef256fa15bfd4d6951f209080b25741c2df84abc6ef0507dc74687b6eb96409c8be1d15a', 'student'),
('it_sneha@placify.com', 'scrypt:32768:8:1$6tA52IC70zvhwOuN$cf5e16c24e1b2b9c080992466f10413ce66c6c96dbff24225aced7bbef256fa15bfd4d6951f209080b25741c2df84abc6ef0507dc74687b6eb96409c8be1d15a', 'student'),
('ec_aisha@placify.com', 'scrypt:32768:8:1$6tA52IC70zvhwOuN$cf5e16c24e1b2b9c080992466f10413ce66c6c96dbff24225aced7bbef256fa15bfd4d6951f209080b25741c2df84abc6ef0507dc74687b6eb96409c8be1d15a', 'student'),
('me_vikram@placify.com', 'scrypt:32768:8:1$6tA52IC70zvhwOuN$cf5e16c24e1b2b9c080992466f10413ce66c6c96dbff24225aced7bbef256fa15bfd4d6951f209080b25741c2df84abc6ef0507dc74687b6eb96409c8be1d15a', 'student')
ON CONFLICT (email) DO NOTHING;

-- Company user (password: microsoft123)
INSERT INTO users (email, password_hash, role, company_id) VALUES
('microsoft@placify.com', 'scrypt:32768:8:1$0IF51HjJ1J4W9osm$c264a96514b97a8827a57ab1223468b14d8b6d2be5cf05b2c45c1f9d6690dff4c1fc05a385531c6d83dbb0f3d1ed551ae0d968bc8e5e83abb2c585bd1c2390e7', 'company',
    (SELECT company_id FROM companies WHERE name = 'Microsoft'))
ON CONFLICT (email) DO NOTHING;

-- Student profiles
INSERT INTO students (user_id, roll_number, name, email, phone, gender, dob, department, batch_year, cgpa, backlogs) VALUES
((SELECT user_id FROM users WHERE email='student@placify.com'), 'S2025001', 'Satvik Student', 'student@placify.com', '9999999999', 'male', '2004-01-01', 'CSE', 2025, 9.2, 0),
((SELECT user_id FROM users WHERE email='cs_arjun@placify.com'), 'S2025002', 'Arjun Sharma', 'cs_arjun@placify.com', '9999999998', 'male', '2004-03-15', 'CSE', 2025, 8.8, 0),
((SELECT user_id FROM users WHERE email='it_sneha@placify.com'), 'S2025003', 'Sneha Pillai', 'it_sneha@placify.com', '9999999997', 'female', '2004-06-20', 'IT', 2025, 9.3, 0),
((SELECT user_id FROM users WHERE email='ec_aisha@placify.com'), 'S2025004', 'Aisha Khan', 'ec_aisha@placify.com', '9999999996', 'female', '2004-02-10', 'ECE', 2025, 8.5, 0),
((SELECT user_id FROM users WHERE email='me_vikram@placify.com'), 'S2025005', 'Vikram Patel', 'me_vikram@placify.com', '9999999995', 'male', '2004-09-05', 'ME', 2025, 7.8, 0)
ON CONFLICT (roll_number) DO NOTHING;
