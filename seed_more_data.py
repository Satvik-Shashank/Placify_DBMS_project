import sys
import os
from datetime import datetime, timedelta
import random

# Ensure we can import from BACKEND
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db import execute_query

def seed_data():
    print("Fetching existing data...")
    # Get students
    students_res = execute_query("SELECT student_id, email, name, cgpa FROM students")
    if not students_res['success'] or not students_res['data']:
        print("No students found. Run setup_db.py first.")
        return
    students = {s['email']: s for s in students_res['data']}

    # Get companies
    companies_res = execute_query("SELECT company_id, name, is_dream, ctc_lpa FROM companies")
    if not companies_res['success'] or not companies_res['data']:
        print("No companies found.")
        return
    companies = {c['name']: c for c in companies_res['data']}
    
    # Get skills
    skills_res = execute_query("SELECT skill_id, skill_name FROM skills")
    skills = {s['skill_name']: s['skill_id'] for s in skills_res['data']} if skills_res['success'] else {}

    now = datetime.now()

    print("Adding student skills...")
    # Satvik
    satvik = students.get('student@placify.com')
    if satvik:
        for skill, prof in [('Python', 'expert'), ('React', 'advanced'), ('Machine Learning', 'intermediate')]:
            if skill in skills:
                execute_query("INSERT IGNORE INTO student_skills (student_id, skill_id, proficiency) VALUES (%s, %s, %s)", (satvik['student_id'], skills[skill], prof))
    
    # Sneha
    sneha = students.get('it_sneha@placify.com')
    if sneha:
        for skill, prof in [('Node.js', 'expert'), ('MongoDB', 'advanced'), ('AWS', 'intermediate')]:
            if skill in skills:
                execute_query("INSERT IGNORE INTO student_skills (student_id, skill_id, proficiency) VALUES (%s, %s, %s)", (sneha['student_id'], skills[skill], prof))

    # Arjun
    arjun = students.get('cs_arjun@placify.com')
    if arjun:
        for skill, prof in [('Java', 'advanced'), ('SQL', 'intermediate')]:
            if skill in skills:
                execute_query("INSERT IGNORE INTO student_skills (student_id, skill_id, proficiency) VALUES (%s, %s, %s)", (arjun['student_id'], skills[skill], prof))
                
    # Vikram
    vikram = students.get('me_vikram@placify.com')
    if vikram:
        for skill, prof in [('AutoCAD', 'advanced')]:
            if skill in skills:
                execute_query("INSERT IGNORE INTO student_skills (student_id, skill_id, proficiency) VALUES (%s, %s, %s)", (vikram['student_id'], skills[skill], prof))


    print("Creating rounds...")
    # Define rounds for a few companies
    company_rounds = {}
    for c_name, c_data in companies.items():
        cid = c_data['company_id']
        r1 = execute_query("INSERT IGNORE INTO rounds (company_id, round_number, round_type, round_name, scheduled_date, status) VALUES (%s, 1, 'aptitude', 'Aptitude Test', %s, 'completed')", (cid, now - timedelta(days=10)))
        r2 = execute_query("INSERT IGNORE INTO rounds (company_id, round_number, round_type, round_name, scheduled_date, status) VALUES (%s, 2, 'technical', 'Technical Interview', %s, 'completed')", (cid, now - timedelta(days=5)))
        
        # Get round IDs
        r_ids = execute_query("SELECT round_id, round_number FROM rounds WHERE company_id=%s ORDER BY round_number", (cid,))
        if r_ids['success']:
            company_rounds[c_name] = r_ids['data']

    def add_application(student, company_name, status, applied_days_ago):
        if not student or company_name not in companies: return None
        cid = companies[company_name]['company_id']
        res = execute_query("INSERT IGNORE INTO applications (student_id, company_id, status, applied_at) VALUES (%s, %s, %s, %s)", 
                            (student['student_id'], cid, status, now - timedelta(days=applied_days_ago)))
        if res['success'] and res['lastrowid']:
            return res['lastrowid']
        # If already exists, fetch it
        fetch_res = execute_query("SELECT application_id FROM applications WHERE student_id=%s AND company_id=%s", (student['student_id'], cid))
        if fetch_res['success'] and fetch_res['data']:
            # update status
            execute_query("UPDATE applications SET status=%s WHERE application_id=%s", (status, fetch_res['data'][0]['application_id']))
            return fetch_res['data'][0]['application_id']
        return None

    def add_round_result(app_id, round_id, status, score, attended=True):
        execute_query("INSERT IGNORE INTO round_results (round_id, application_id, status, score, attended) VALUES (%s, %s, %s, %s, %s) ON DUPLICATE KEY UPDATE status=%s, score=%s, attended=%s", 
                      (round_id, app_id, status, score, attended, status, score, attended))

    def add_offer(app_id, ctc, role, status='pending', accepted_days_ago=None):
        if status == 'accepted':
            acc_at = now - timedelta(days=accepted_days_ago) if accepted_days_ago else now
            execute_query("INSERT IGNORE INTO offers (application_id, offered_ctc, offered_role, status, acceptance_deadline, accepted_at) VALUES (%s, %s, %s, %s, %s, %s)", 
                          (app_id, ctc, role, status, now + timedelta(days=7), acc_at))
            # Also update student placement status
            execute_query("UPDATE students SET is_placed=TRUE, placement_type='dream' WHERE student_id=(SELECT student_id FROM applications WHERE application_id=%s)", (app_id,))
        else:
            execute_query("INSERT IGNORE INTO offers (application_id, offered_ctc, offered_role, status, acceptance_deadline) VALUES (%s, %s, %s, %s, %s)", 
                          (app_id, ctc, role, status, now + timedelta(days=7)))

    print("Adding applications and results...")
    
    # 1. Satvik -> Microsoft (Selected & Offer Accepted)
    app_ms_satvik = add_application(satvik, 'Microsoft', 'selected', 15)
    if app_ms_satvik and 'Microsoft' in company_rounds:
        rds = company_rounds['Microsoft']
        if len(rds) >= 2:
            add_round_result(app_ms_satvik, rds[0]['round_id'], 'shortlisted', 92)
            add_round_result(app_ms_satvik, rds[1]['round_id'], 'shortlisted', 88)
        add_offer(app_ms_satvik, 44.0, 'Software Engineer', 'accepted', 2)

    # Satvik -> Google (In Progress)
    app_g_satvik = add_application(satvik, 'Google India', 'in_progress', 12)
    if app_g_satvik and 'Google India' in company_rounds:
        rds = company_rounds['Google India']
        if len(rds) >= 2:
            add_round_result(app_g_satvik, rds[0]['round_id'], 'shortlisted', 89)
            add_round_result(app_g_satvik, rds[1]['round_id'], 'pending', None)

    # Satvik -> Amazon (Rejected)
    app_amz_satvik = add_application(satvik, 'Amazon', 'rejected', 14)
    if app_amz_satvik and 'Amazon' in company_rounds:
        rds = company_rounds['Amazon']
        if len(rds) >= 2:
            add_round_result(app_amz_satvik, rds[0]['round_id'], 'rejected', 45)

    # 2. Sneha -> Microsoft (In progress)
    app_ms_sneha = add_application(sneha, 'Microsoft', 'in_progress', 13)
    if app_ms_sneha and 'Microsoft' in company_rounds:
        rds = company_rounds['Microsoft']
        if len(rds) >= 2:
            add_round_result(app_ms_sneha, rds[0]['round_id'], 'shortlisted', 95)
            add_round_result(app_ms_sneha, rds[1]['round_id'], 'pending', None)

    # 3. Arjun -> Infosys (Selected, pending offer)
    app_inf_arjun = add_application(arjun, 'Infosys', 'selected', 20)
    if app_inf_arjun and 'Infosys' in company_rounds:
        rds = company_rounds['Infosys']
        if len(rds) >= 2:
            add_round_result(app_inf_arjun, rds[0]['round_id'], 'shortlisted', 80)
            add_round_result(app_inf_arjun, rds[1]['round_id'], 'shortlisted', 75)
        add_offer(app_inf_arjun, 3.6, 'Systems Engineer', 'pending')

    # Arjun -> TCS (Selected, declined offer)
    app_tcs_arjun = add_application(arjun, 'Tata Consultancy Services', 'selected', 22)
    if app_tcs_arjun and 'Tata Consultancy Services' in company_rounds:
        rds = company_rounds['Tata Consultancy Services']
        if len(rds) >= 2:
            add_round_result(app_tcs_arjun, rds[0]['round_id'], 'shortlisted', 78)
            add_round_result(app_tcs_arjun, rds[1]['round_id'], 'shortlisted', 82)
        add_offer(app_tcs_arjun, 3.36, 'Assistant System Engineer', 'declined')

    # 4. Aisha -> BHEL (Applied)
    app_bhel_aisha = add_application(students.get('ec_aisha@placify.com'), 'BHEL', 'applied', 5)
    
    # 5. Vikram -> BHEL (Selected, pending)
    app_bhel_vikram = add_application(vikram, 'BHEL', 'selected', 25)
    if app_bhel_vikram and 'BHEL' in company_rounds:
        rds = company_rounds['BHEL']
        if len(rds) >= 2:
            add_round_result(app_bhel_vikram, rds[0]['round_id'], 'shortlisted', 88)
            add_round_result(app_bhel_vikram, rds[1]['round_id'], 'shortlisted', 85)
        add_offer(app_bhel_vikram, 6.5, 'Engineer Trainee', 'pending')

    print("Populating communications/logs (audit_logs)...")
    execute_query("INSERT IGNORE INTO audit_logs (table_name, action_type, record_id, new_values) VALUES ('communications', 'INSERT', 1, '{\"message\": \"Offer rolled out to Satvik\"}')")

    print("Data seeding complete!")

if __name__ == '__main__':
    seed_data()
