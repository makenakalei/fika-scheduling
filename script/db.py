import psycopg2
from psycopg2.extras import RealDictCursor

def get_connection():
    return psycopg2.connect(
        dbname="user_schedule",
        user="postgres",
        password="postgres",
        host="localhost",
        cursor_factory=RealDictCursor
    )

# ----------- USERS -----------

def fetch_user_prefs(user_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT time_pref, stress_base, work_pref, sleep_goal, sleep_pref
        FROM users
        WHERE id = %s
    """, (user_id,))
    row = cur.fetchone()
    conn.close()
    return {
        "focus_period": row["time_pref"],
        "stress_level": row["stress_base"],
        "work_style": row["work_pref"],
        "sleep_goal": row["sleep_goal"],
        "sleep_pref": row["sleep_pref"]
    }

# ----------- TASKS -----------

def fetch_tasks(user_id):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, category, estimated_time, deadline, fixed_time,
               start_time, end_time, priority, description, stress_entry
        FROM tasks
        WHERE user_id = %s AND archived = false
        ORDER BY fixed_time DESC, deadline ASC, priority DESC
    """, (user_id,))
    rows = cur.fetchall()
    conn.close()
    return rows  # list of dicts

# ----------- SCHEDULED TASKS -----------

def store_schedule(user_id, schedule):
    conn = get_connection()
    cur = conn.cursor()
    for entry in schedule:
        cur.execute("""
            INSERT INTO scheduled_tasks (user_id, task_id, start_time, end_time, type)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            user_id,
            entry['task_id'],
            entry['start'],
            entry['end'],
            entry['type']
        ))
    conn.commit()
    conn.close()

# ----------- OPTIONAL: STRESS FEEDBACK INSERT -----------

def log_stress_entry(task_id, stress_entry):
    """Update a task with a reported stress entry (if tracked)."""
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE tasks
        SET stress_entry = %s
        WHERE id = %s
    """, (stress_entry, task_id))
    conn.commit()
    conn.close()