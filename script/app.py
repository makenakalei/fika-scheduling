from fastapi import FastAPI
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor

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
def log_mood():
    pass
@app.get("/journal")
def get_mood():
    pass