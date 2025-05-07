from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime, date as cdate, timedelta
from passlib.context import CryptContext
import jwt as PyJWT
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

from db import get_connection 
from db import fetch_tasks, log_stress_entry, fetch_user_prefs, store_schedule
from scheduler import generate_schedule

app = FastAPI()

# JWT Configuration
SECRET_KEY = "your-secret-key-here"  # Change this to a secure secret key
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = PyJWT.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# Login Models
class LoginRequest(BaseModel):
    username_or_email: str
    password: str

class Token(BaseModel):
    user_id: int
    username: str
    email: str
    token: str
    token_type: str = "bearer"

# Signup Models
class InitialSignupRequest(BaseModel):
    username: str
    email: EmailStr
    password: str
    firstName: str
    lastName: str
    gender: Optional[int] = 0  # 0: Male, 1: Female, 2: Non-binary, 3: Other
    birthday: Optional[cdate] = None
    time_pref: Optional[int] = None  # 0: Morning, 1: Afternoon, 2: Night
    work_pref: Optional[str] = None  # "Long Focused Blocks" or "Short Sprints"
    stress_base: Optional[int] = None  # 1-10

class UserPreferencesRequest(BaseModel):
    workTimePreference: str  # "Morning", "Afternoon", or "Night"
    goalSleepHours: int
    goalSleepTime: str  # Time in HH:MM format
    occupation: str
    stressBaseLevel: int  # 1-10

class SignupResponse(BaseModel):
    user_id: int
    username: str
    email: str
    token: str
    token_type: str = "bearer"

# Pydantic Models
class User(BaseModel):
    username: str
    password: str  # Should be hashed before storing
    email: EmailStr
    name: str
    lname: str
    gender: Optional[str] = None
    time_pref: Optional[int] = None
    stress_base: Optional[int] = None
    work_pref: Optional[str] = None
    sleep_pref: Optional[int] = None
    sleep_goal: Optional[int] = None
    occupation: Optional[str] = None
    birthday: Optional[cdate] = None

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
    user_id: int
    task_id: Optional[int] = None
    stress_level: int
    date: Optional[cdate] = None

class UserPreferences(BaseModel):
    workTimePreference: str
    workStylePreference: str
    goalSleepHours: int
    goalSleepTime: str
    occupation: str
    stressBaseLevel: int

class ScheduleItem(BaseModel):
    task_id: Optional[int]
    task: str
    start: str
    end: str
    type: str  # "Fixed", "Flexible", or "Break"

# --- ROUTES ---

# User Routes
@app.post("/users/")
def create_user(user: User):
    conn = get_connection()
    cur = conn.cursor()
    # Check for existing email or username
    cur.execute("SELECT id FROM users WHERE email = %s", (user.email,))
    if cur.fetchone():
        raise HTTPException(status_code=400, detail="Email already registered")
    cur.execute("SELECT id FROM users WHERE username = %s", (user.username,))
    if cur.fetchone():
        raise HTTPException(status_code=400, detail="Username already taken")
    # Hash the password before storing
    hashed_pw = hash_password(user.password)
    cur.execute("""
        INSERT INTO users (
            username, password, email, name, lname, gender, time_pref, stress_base, work_pref, sleep_pref, sleep_goal, occupation, birthday, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
        RETURNING id, username, email, name, lname, gender, time_pref, stress_base, work_pref, sleep_pref, sleep_goal, occupation, birthday, created_at
    """, (
        user.username, hashed_pw, user.email, user.name, user.lname, user.gender, user.time_pref, user.stress_base, user.work_pref, user.sleep_pref, user.sleep_goal, user.occupation, user.birthday
    ))
    new_user = cur.fetchone()
    conn.commit()
    conn.close()
    return {"message": "User created successfully!", "user": new_user}

# Updated User Routes
@app.post("/signup/initial", response_model=SignupResponse)
def initial_signup(signup_data: InitialSignupRequest):
    conn = get_connection()
    cur = conn.cursor()
    
    # Check for existing email or username
    cur.execute("SELECT id FROM users WHERE email = %s", (signup_data.email,))
    if cur.fetchone():
        raise HTTPException(status_code=400, detail="Email already registered")
    
    cur.execute("SELECT id FROM users WHERE username = %s", (signup_data.username,))
    if cur.fetchone():
        raise HTTPException(status_code=400, detail="Username already taken")
    
    # Hash the password before storing
    hashed_pw = hash_password(signup_data.password)
    
    # Set default values for required fields
    default_sleep_pref = 8  # Default 8 hours of sleep
    default_sleep_goal = "22:00"  # Default sleep time
    default_occupation = "Student"  # Default occupation
    
    # Insert the initial user data with default values for required fields
    cur.execute("""
        INSERT INTO users (
            username, password, email, name, lname, gender, birthday, time_pref, stress_base, 
            work_pref, sleep_pref, sleep_goal, occupation, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::time, %s, CURRENT_TIMESTAMP)
        RETURNING id, username, email
    """, (
        signup_data.username, hashed_pw, signup_data.email,
        signup_data.firstName, signup_data.lastName,
        signup_data.gender, signup_data.birthday, signup_data.time_pref, 
        signup_data.stress_base, signup_data.work_pref, default_sleep_pref, default_sleep_goal,
        default_occupation
    ))
    
    new_user = cur.fetchone()
    conn.commit()
    
    # Create access token
    access_token = create_access_token(
        data={"sub": str(new_user["id"]), "username": new_user["username"]}
    )
    
    conn.close()
    
    return {
        "user_id": new_user["id"],
        "username": new_user["username"],
        "email": new_user["email"],
        "token": access_token,
        "token_type": "bearer"
    }

@app.post("/signup/preferences/{user_id}")
def complete_signup(user_id: int, preferences: UserPreferences):
    conn = get_connection()
    cur = conn.cursor()
    
    try:
        # Verify user exists
        cur.execute("SELECT id FROM users WHERE id = %s", (user_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="User not found")
        
        # Map work time preference to integer
        time_pref_map = {"Morning": 0, "Afternoon": 1, "Night": 2}
        time_pref = time_pref_map.get(preferences.workTimePreference, 0)
        
        # Map work style preference to string
        work_style_map = {"long_chunks": "Long Focused Blocks", "short_sprints": "Short Sprints"}
        work_pref = work_style_map.get(preferences.workStylePreference, "Long Focused Blocks")
        
        # Ensure sleep_goal is in HH:00 format
        try:
            # Try to parse the time string
            if ":" in preferences.goalSleepTime:
                hour = preferences.goalSleepTime.split(":")[0]
                sleep_goal = f"{hour}:00"
            else:
                # If it's not in the correct format, use a default
                sleep_goal = "22:00"
        except Exception:
            sleep_goal = "22:00"
        
        # Update user preferences
        cur.execute("""
            UPDATE users 
            SET work_pref = %s,
                sleep_pref = %s,
                sleep_goal = %s::time,
                occupation = %s,
                stress_base = %s
            WHERE id = %s
        """, (
            work_pref,
            preferences.goalSleepHours,
            sleep_goal,
            preferences.occupation,
            preferences.stressBaseLevel,
            user_id
        ))
        
        conn.commit()
        return {"message": "Preferences updated successfully"}
        
    except Exception as e:
        conn.rollback()
        print(f"Error in complete_signup: {str(e)}")  # Add debug logging
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

# Task Routes
@app.post("/tasks/")
def create_task(task: Task, token: str = Depends(oauth2_scheme)):
    try:
        # Decode the JWT token to get the user ID
        payload = PyJWT.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload["sub"])
        
        conn = get_connection()
        cur = conn.cursor()
        
        # Verify user exists
        cur.execute("SELECT id FROM users WHERE id = %s", (user_id,))
        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="User not found")
        
        # Create task with the authenticated user's ID
        cur.execute("""
            INSERT INTO tasks (
                name, category, estimated_time, deadline, fixed_time, priority,
                start_time, end_time, description, divided, archived, stress_entry, user_id
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            task.name, task.category, task.estimated_time, task.deadline,
            task.fixed_time, task.priority, task.start_time, task.end_time,
            task.description, task.divided, task.archived, task.stress_entry, user_id
        ))
        conn.commit()
        conn.close()
        return {"message": "Task added!"}
    except PyJWT.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid authentication token")

@app.get("/tasks/")
def get_all_tasks(user_id: int):
    tasks = fetch_tasks(user_id)
    return {"tasks": tasks}

@app.get("/tasks/{task_id}")
def get_task(task_id: int):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM tasks WHERE id = %s", (task_id,))
    task = cur.fetchone()
    conn.close()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return {"task": task}

@app.put("/tasks/{task_id}")
def update_task(task_id: int, task: Task):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE tasks SET
            name = %s, category = %s, estimated_time = %s, deadline = %s,
            fixed_time = %s, priority = %s, start_time = %s, end_time = %s,
            description = %s, divided = %s, archived = %s, stress_entry = %s
        WHERE id = %s
        RETURNING *
    """, (
        task.name, task.category, task.estimated_time, task.deadline,
        task.fixed_time, task.priority, task.start_time, task.end_time,
        task.description, task.divided, task.archived, task.stress_entry, task_id
    ))
    updated_task = cur.fetchone()
    conn.commit()
    conn.close()
    if updated_task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return {"message": "Task updated!", "task": updated_task}

@app.delete("/tasks/{task_id}")
def delete_task(task_id: int):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM tasks WHERE id = %s RETURNING *", (task_id,))
    deleted_task = cur.fetchone()
    conn.commit()
    conn.close()
    if deleted_task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return {"message": "Task deleted!", "task": deleted_task}

@app.get("/tasks/archived_count/")
def get_archived_count(user_id: int):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) as count FROM tasks WHERE user_id = %s AND archived = TRUE", (user_id,))
    row = cur.fetchone()
    count = row["count"] if row and "count" in row else 0
    conn.close()
    return {"archived_count": count}

# User Preferences Routes
@app.post("/preferences/")
def create_preferences(prefs: UserPreferences):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO user_preferences (
            user_id, work_style, focus_period, stress_level,
            break_preference, work_block_preference
        ) VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (user_id) DO UPDATE SET
            work_style = EXCLUDED.work_style,
            focus_period = EXCLUDED.focus_period,
            stress_level = EXCLUDED.stress_level,
            break_preference = EXCLUDED.break_preference,
            work_block_preference = EXCLUDED.work_block_preference
        RETURNING *
    """, (
        prefs.user_id, prefs.work_style, prefs.focus_period,
        prefs.stress_level, prefs.break_preference, prefs.work_block_preference
    ))
    preferences = cur.fetchone()
    conn.commit()
    conn.close()
    return {"message": "Preferences saved!", "preferences": preferences}

@app.get("/preferences/{user_id}")
def get_preferences(user_id: int):
    preferences = fetch_user_prefs(user_id)
    if preferences is None:
        raise HTTPException(status_code=404, detail="Preferences not found")
    return {"preferences": preferences}

# Schedule Routes
@app.post("/schedule/generate/{user_id}")
def create_schedule(user_id: int):
    try:
        # First, clear existing scheduled tasks for this user
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM scheduled_tasks WHERE user_id = %s", (user_id,))
        conn.commit()
        conn.close()
        
        # Generate and store new schedule
        schedule = generate_schedule(user_id)
        return {"message": "Schedule generated!", "schedule": schedule}
    except Exception as e:
        print("Error in create_schedule:", e)
        import traceback; traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/schedule/{user_id}")
def get_schedule(user_id: int):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT * FROM scheduled_tasks 
        WHERE user_id = %s 
        ORDER BY start_time ASC
    """, (user_id,))
    schedule = cur.fetchall()
    conn.close()
    return {"schedule": schedule if schedule else []}

# Mood Tracking Routes
@app.post("/mood/")
def log_mood(mood_entry: Entry):
    conn = get_connection()
    cur = conn.cursor()

    if mood_entry.task_id:
        cur.execute("SELECT id FROM tasks WHERE id = %s", (mood_entry.task_id,))
        if cur.fetchone() is None:
            raise HTTPException(status_code=404, detail="Task ID not found")

    cur.execute("""
        INSERT INTO mood_tracking (user_id, task_id, stress_level, date)
        VALUES (%s, %s, %s, COALESCE(%s, CURRENT_DATE))
        RETURNING id
    """, (mood_entry.user_id, mood_entry.task_id, mood_entry.stress_level, mood_entry.date))
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

# Login Route
@app.post("/login", response_model=Token)
def login(login_data: LoginRequest):
    conn = get_connection()
    cur = conn.cursor()
    
    try:
        # Try to find user by username or email
        cur.execute("""
            SELECT id, username, email, password 
            FROM users 
            WHERE username = %s OR email = %s
        """, (login_data.username_or_email, login_data.username_or_email))
        
        user = cur.fetchone()
        
        if not user:
            raise HTTPException(
                status_code=401,
                detail="Invalid username or email"
            )
        
        if not verify_password(login_data.password, user["password"]):
            raise HTTPException(
                status_code=401,
                detail="Invalid password"
            )
        
        # Create access token
        access_token = create_access_token(
            data={"sub": str(user["id"]), "username": user["username"]}
        )
        
        return {
            "user_id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "token": access_token,
            "token_type": "bearer"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cur.close()
        conn.close()

# Health Check Route
@app.get("/health")
def health_check():
    return {"status": "healthy"}
