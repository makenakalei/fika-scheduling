from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, date as cdate

from db import get_connection  # For fallback operations
from db import fetch_tasks, log_stress_entry  # Your refactored functions

app = FastAPI()

# Pydantic Models
class Task(BaseModel):
    name: str
    category: str
    estimated_time: int
    deadline: Optional[datetime] = None
    fixed_time: Optional[bool] = False
    priority: str
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    description: Optional[str] = None
    divided: Optional[bool] = False
    archived: Optional[bool] = False
    stress_entry: Optional[int] = None
    user_id: int

class Entry(BaseModel):
    task_id: Optional[int] = None
    stress_level: int
    date: Optional[cdate] = None

# --- ROUTES ---

@app.post("/tasks/")
def create_task(task: Task):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO tasks (
            name, category, estimated_time, deadline, fixed_time, priority,
            start_time, end_time, description, divided, archived, stress_entry, user_id
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING *
    """, (
        task.name, task.category, task.estimated_time, task.deadline,
        task.fixed_time, task.priority, task.start_time, task.end_time,
        task.description, task.divided, task.archived, task.stress_entry, task.user_id
    ))
    new_task = cur.fetchone()
    conn.commit()
    conn.close()
    return {"message": "Task added!", "task": new_task}

@app.get("/tasks/")
def get_all_tasks(user_id: int):
    tasks = fetch_tasks(user_id)
    return {"tasks": tasks}

@app.post("/mood/")
def log_mood(mood_entry: Entry):
    conn = get_connection()
    cur = conn.cursor()

    if mood_entry.task_id:
        cur.execute("SELECT id FROM tasks WHERE id = %s", (mood_entry.task_id,))
        if cur.fetchone() is None:
            raise HTTPException(status_code=404, detail="Task ID not found")

    cur.execute("""
        INSERT INTO mood_tracking (task_id, stress_level, date)
        VALUES (%s, %s, COALESCE(%s, CURRENT_DATE))
        RETURNING id
    """, (mood_entry.task_id, mood_entry.stress_level, mood_entry.date))
    mood_id = cur.fetchone()["id"]

    conn.commit()
    conn.close()
    return {"message": "Mood logged!", "mood_id": mood_id}

@app.get("/mood/")
def get_all_moods():
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM mood_tracking")
    moods = cur.fetchall()
    conn.close()
    return {"moods": moods}

@app.get("/mood/{task_id}")
def get_mood_for_task(task_id: int):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, stress_level, date, timestamp
        FROM mood_tracking
        WHERE task_id = %s
    """, (task_id,))
    logs = cur.fetchall()
    conn.close()
    return {"task_id": task_id, "mood_logs": logs}
