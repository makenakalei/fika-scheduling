import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
import pandas as pd
import ace_tools as tools

# Database connection settings 
conn = psycopg2.connect(
    dbname="user_schedule",
    user="postgres",
    password="postgres",
    host="localhost",
    cursor_factory=RealDictCursor
)
cur = conn.cursor()

def fetch_user_prefs(user_id):
    """Fetch user preferences from the database."""
    cur.execute("SELECT time_pref, stress_base, work_pref FROM users WHERE id = %s", (user_id,))
    user_prefs = cur.fetchone()
    conn.close()
    return {
        "focus_period": user_prefs[0],
        "stress_level": user_prefs[1],
        "work_style": user_prefs[2]
    }

def fetch_tasks(user_id):
    """Fetch the user's pending tasks from the database."""
    cur.execute("""
        SELECT id, name, category, estimated_time, deadline, fixed_time, priority, start_time, end_time
        FROM tasks WHERE user_id = %s AND archived = false ORDER BY fixed_time DESC, deadline ASC, priority DESC
    """, (user_id,))
    tasks = [dict(zip([desc[0] for desc in cur.description], row)) for row in cur.fetchall()]
    conn.close()
    return tasks

def store_schedule(user_id, schedule):
    """Store the generated schedule in the database."""
    for entry in schedule:
        cur.execute("""
            INSERT INTO scheduled_tasks (user_id, task_id, start_time, end_time, type)
            VALUES (%s, %s, %s, %s, %s)
        """, (user_id, entry['task_id'], entry['start'], entry['end'], entry['type']))
    
    conn.commit()
    conn.close()

def generate_schedule(user_id):
    """Generate a heuristic-based schedule using database data."""
    
    # Fetch user preferences and tasks
    user_prefs = fetch_user_prefs(user_id)
    tasks = fetch_tasks(user_id)
    
    # Define general work slots based on focus period
    focus_mapping = {"morning": (8, 12), "afternoon": (10, 14), "evening": (12, 16)}
    work_slots = [focus_mapping.get(user_prefs['focus_period'], (8, 12)), (13, 17)]
    
    # Define work session lengths
    work_block = 90 if user_prefs['work_style'] == "long_chunks" else 45
    break_time = 30 if user_prefs['work_style'] == "long_chunks" else 10
    if user_prefs['stress_level'] >= 7:
        break_time += 10  # Extra breaks for higher stress levels
    
    # Sort tasks by priority and deadline
    schedule = []
    current_time = datetime.strptime("08:00", "%H:%M")
    
    for slot in work_slots:
        start, end = slot
        current_time = current_time.replace(hour=start, minute=0)
        
        while current_time.hour < end and tasks:
            task = tasks.pop(0)
            task_duration = task.get('estimated_time', 30)
            
            if task['fixed_time']:
                fixed_start = datetime.strptime(task['start_time'], "%H:%M")
                fixed_end = datetime.strptime(task['end_time'], "%H:%M")
                schedule.append({"task_id": task['id'], "task": task['name'], "start": fixed_start.strftime("%Y-%m-%d %H:%M"), "end": fixed_end.strftime("%Y-%m-%d %H:%M"), "type": "Fixed"})
                current_time = fixed_end
            else:
                task_end_time = current_time + timedelta(minutes=task_duration)
                schedule.append({"task_id": task['id'], "task": task['name'], "start": current_time.strftime("%Y-%m-%d %H:%M"), "end": task_end_time.strftime("%Y-%m-%d %H:%M"), "type": "Flexible"})
                current_time = task_end_time
                
                if user_prefs['work_style'] == "short_sprints" or (user_prefs['work_style'] == "long_chunks" and (current_time.minute % work_block == 0)):
                    schedule.append({"task_id": None, "task": "Break", "start": current_time.strftime("%Y-%m-%d %H:%M"), "end": (current_time + timedelta(minutes=break_time)).strftime("%Y-%m-%d %H:%M"), "type": "Break"})
                    current_time += timedelta(minutes=break_time)
    
    # Store the schedule in the database
    store_schedule(user_id, schedule)
    return schedule

# Example usage
user_id = 1  # Replace with actual user ID
schedule = generate_schedule(user_id)

# Display schedule
tools.display_dataframe_to_user(name="Generated Schedule", dataframe=pd.DataFrame(schedule))
