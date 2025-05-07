from datetime import datetime, timedelta
import pandas as pd
import datetime

from helpers import evaluate_schedule

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
    today = datetime.datetime.now().date()
    day_start = datetime.datetime.combine(today, datetime.time(hour=8, minute=0))
    day_end = datetime.datetime.combine(today, datetime.time(hour=22, minute=0))

    # Separate fixed and flexible tasks
    fixed_tasks = [t for t in tasks if t['fixed_time']]
    flexible_tasks = [t for t in tasks if not t['fixed_time']]

    # Schedule all fixed tasks first, sorted by start time
    fixed_blocks = []
    for t in fixed_tasks:
        fixed_start = t['start_time']
        fixed_end = t.get('end_time')
        if isinstance(fixed_start, str):
            fixed_start = datetime.datetime.fromisoformat(fixed_start)
        if fixed_end is None:
            deadline = t.get("deadline")
            if deadline:
                if isinstance(deadline, str):
                    try:
                        fixed_end = datetime.datetime.fromisoformat(deadline)
                    except Exception:
                        fixed_end = fixed_start + timedelta(hours=1)
                else:
                    fixed_end = deadline
            else:
                fixed_end = fixed_start + timedelta(hours=1)
        elif isinstance(fixed_end, str):
            fixed_end = datetime.datetime.fromisoformat(fixed_end)
        fixed_blocks.append((fixed_start, fixed_end, t))
    fixed_blocks.sort(key=lambda x: x[0])
    for start, end, t in fixed_blocks:
        schedule.append({
            "task_id": t['id'],
            "task": t['name'],
            "start": start.strftime("%Y-%m-%d %H:%M"),
            "end": end.strftime("%Y-%m-%d %H:%M"),
            "type": "Fixed"
        })

    # Find all gaps between fixed tasks
    gaps = []
    prev_end = day_start
    for start, end, _ in fixed_blocks:
        if prev_end < start:
            gaps.append((prev_end, start))
        prev_end = max(prev_end, end)
    if prev_end < day_end:
        gaps.append((prev_end, day_end))

    # Create the RL agent for flexible tasks
    action_space = list(range(len(flexible_tasks))) + ["break"]
    agent = SchedulerAgent(action_space)

    # Schedule flexible tasks and breaks in the gaps
    for gap_start, gap_end in gaps:
        current_time = gap_start
        while current_time < gap_end and flexible_tasks:
            state = build_state(current_time, flexible_tasks, user_prefs)
            action = agent.select_action(state)
            if action == "break":
                break_end = current_time + timedelta(minutes=break_time)
                if break_end > gap_end:
                    break  # Don't overflow the gap
                schedule.append({
                    "task_id": None,
                    "task": "Break",
                    "start": current_time.strftime("%Y-%m-%d %H:%M"),
                    "end": break_end.strftime("%Y-%m-%d %H:%M"),
                    "type": "Break"
                })
                reward = 0.05
                next_state = build_state(break_end, flexible_tasks, user_prefs)
                agent.update(state, action, reward, next_state)
                current_time = break_end
            else:
                try:
                    action_idx = int(action)
                    if not (0 <= action_idx < len(flexible_tasks)):
                        continue  # skip invalid action
                    task = flexible_tasks.pop(action_idx)
                    task_duration = task.get('estimated_time', 30)
                    task_end_time = current_time + timedelta(minutes=task_duration)
                    if task_end_time > gap_end:
                        break  # Don't overflow the gap
                    schedule.append({
                        "task_id": task['id'],
                        "task": task['name'],
                        "start": current_time.strftime("%Y-%m-%d %H:%M"),
                        "end": task_end_time.strftime("%Y-%m-%d %H:%M"),
                        "type": "Flexible"
                    })
                    reward = 1.0
                    next_state = build_state(task_end_time, flexible_tasks, user_prefs)
                    agent.update(state, action, reward, next_state)
                    current_time = task_end_time
                    if user_prefs['work_style'] == "short_sprints" or (
                        user_prefs['work_style'] == "long_chunks" and current_time.minute % work_block == 0
                    ):
                        break_end = current_time + timedelta(minutes=break_time)
                        if break_end > gap_end:
                            break
                        schedule.append({
                            "task_id": None,
                            "task": "Break",
                            "start": current_time.strftime("%Y-%m-%d %H:%M"),
                            "end": break_end.strftime("%Y-%m-%d %H:%M"),
                            "type": "Break"
                        })
                        current_time = break_end
                except ValueError:
                    continue  # skip invalid action

    store_schedule(user_id, schedule)
    final_reward = evaluate_schedule(schedule, user_prefs)
    agent.update(None, None, final_reward, None)
    return schedule

# Example usage:
if __name__ == "__main__":
    user_id = 2
    schedule = generate_schedule(user_id)

    df = pd.DataFrame(schedule)
    print(df)
