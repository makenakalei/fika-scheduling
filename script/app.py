from fastapi import FastAPI
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Optional
from datetime import date as cdate

app = FastAPI()

# Database connection
conn = psycopg2.connect(
    dbname="user_schedule",
    user="postgres",
    password="postgres",
    host="localhost",
    cursor_factory=RealDictCursor
)
cur = conn.cursor()

# Pydantic Model for Task
class Task(BaseModel):
    name: str
    category: str
    estimated_time: int
    deadline: str
    fixed_time: bool

class Entry(BaseModel):
    task_id: Optional[int] = None  # Task ID is now optional
    stress_level: int  # Required
    date: Optional[cdate] = None 

# Create a new task
@app.post("/tasks/")
def create_task(task: Task):
    cur.execute(
        "INSERT INTO tasks (name, category, estimated_time, deadline, fixed_time) VALUES (%s, %s, %s, %s, %s) RETURNING *",
        (task.name, task.category, task.estimated_time, task.deadline, task.fixed_time)
    )
    new_task = cur.fetchone()
    conn.commit()
    return {"message": "Task added!", "task": new_task}

# Get all tasks
@app.get("/tasks/")
def get_tasks():
    cur.execute("SELECT * FROM tasks")
    tasks = cur.fetchall()
    return {"tasks": tasks}

@app.get("/mood/")
def log_mood(mood_entry: Entry):
    # Ensure task exists if task_id is provided
    if mood_entry.task_id:
        cur.execute("SELECT id FROM tasks WHERE id = %s", (mood_entry.task_id,))
        task = cur.fetchone()
        if not task:
            return {"error": "Task ID not found!"}

    # Use current date if no date is provided
    cur.execute(
        """
        INSERT INTO mood_tracking (task_id, stress_level, date) 
        VALUES (%s, %s, COALESCE(%s, CURRENT_DATE)) RETURNING id
        """,
        (mood_entry.task_id, mood_entry.stress_level, mood_entry.date)
    )
    new_mood_id = cur.fetchone()["id"]

    conn.commit()
    return {"message": "Mood logged!", "mood_id": new_mood_id}


@app.get("/mood/")
def get_mood():
    cur.execute("SELECT * FROM mood_tracking")
    journal = cur.fetchall()
    return{"moods": journal}

@app.get("/mood/{task_id}")
def get_mood_for_task(task_id: int):
    cur.execute("SELECT id, stress_level, date, timestamp FROM mood_tracking WHERE task_id = %s", (task_id,))
    logs = cur.fetchall()
    return {"task_id": task_id, "mood_logs": logs}
    