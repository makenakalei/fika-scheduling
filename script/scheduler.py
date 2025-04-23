from datetime import datetime, timedelta
import pandas as pd


from rl_agent import SchedulerAgent
from db import fetch_user_prefs, fetch_tasks, store_schedule

def build_state(current_time, tasks, user_prefs):
    return {
        "hour": current_time.hour,
        "remaining_tasks": len(tasks),
        "stress": user_prefs["stress_level"],
        "style": 0 if user_prefs["work_style"] == "long_chunks" else 1
    }

def generate_schedule(user_id):
    user_prefs = fetch_user_prefs(user_id)
    tasks = fetch_tasks(user_id)

    focus_mapping = {"morning": (8, 12), "afternoon": (10, 14), "evening": (12, 16)}
    work_slots = [focus_mapping.get(user_prefs['focus_period'], (8, 12)), (13, 17)]
    
    work_block = 90 if user_prefs['work_style'] == "long_chunks" else 45
    break_time = 30 if user_prefs['work_style'] == "long_chunks" else 10
    if user_prefs['stress_level'] >= 7:
        break_time += 10

    schedule = []
    current_time = datetime.strptime("08:00", "%H:%M")

    # Create the RL agent
    action_space = list(range(len(tasks))) + ["break"]
    agent = SchedulerAgent(action_space)

    for slot in work_slots:
        start, end = slot
        current_time = current_time.replace(hour=start, minute=0)

        while current_time.hour < end and tasks:
            state = build_state(current_time, tasks, user_prefs)
            action = agent.select_action(state)

            if action == "break":
                break_end = current_time + timedelta(minutes=break_time)
                schedule.append({
                    "task_id": None,
                    "task": "Break",
                    "start": current_time.strftime("%Y-%m-%d %H:%M"),
                    "end": break_end.strftime("%Y-%m-%d %H:%M"),
                    "type": "Break"
                })
                reward = 0.05
                next_state = build_state(break_end, tasks, user_prefs)
                agent.update(state, action, reward, next_state)
                current_time = break_end
            else:
                if not (0 <= action < len(tasks)):
                    continue  # skip invalid action
                task = tasks.pop(action)
                task_duration = task.get('estimated_time', 30)

                if task['fixed_time']:
                    fixed_start = task['start_time']
                    fixed_end = task['end_time']
                    schedule.append({
                        "task_id": task['id'], "task": task['name'],
                        "start": fixed_start.strftime("%Y-%m-%d %H:%M"),
                        "end": fixed_end.strftime("%Y-%m-%d %H:%M"),
                        "type": "Fixed"
                    })
                    current_time = fixed_end
                else:
                    task_end_time = current_time + timedelta(minutes=task_duration)
                    schedule.append({
                        "task_id": task['id'], "task": task['name'],
                        "start": current_time.strftime("%Y-%m-%d %H:%M"),
                        "end": task_end_time.strftime("%Y-%m-%d %H:%M"),
                        "type": "Flexible"
                    })
                    reward = 1.0
                    next_state = build_state(task_end_time, tasks, user_prefs)
                    agent.update(state, action, reward, next_state)
                    current_time = task_end_time

                    if user_prefs['work_style'] == "short_sprints" or (
                        user_prefs['work_style'] == "long_chunks"
                        and current_time.minute % work_block == 0
                    ):
                        break_end = current_time + timedelta(minutes=break_time)
                        schedule.append({
                            "task_id": None,
                            "task": "Break",
                            "start": current_time.strftime("%Y-%m-%d %H:%M"),
                            "end": break_end.strftime("%Y-%m-%d %H:%M"),
                            "type": "Break"
                        })
                        current_time = break_end

    store_schedule(user_id, schedule)
    return schedule

# Example usage:
if __name__ == "__main__":
    user_id = 2
    schedule = generate_schedule(user_id)

    df = pd.DataFrame(schedule)
    print(df)
