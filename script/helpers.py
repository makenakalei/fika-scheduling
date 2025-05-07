from datetime import datetime

def evaluate_schedule(schedule, user_prefs):
    """
    Compute a global reward for how well a schedule fits user preferences
    and minimizes projected stress.
    """
    reward = 0
    focus_start, focus_end = {"morning": (8, 12), "afternoon": (10, 14), "evening": (12, 16)}.get(
        user_prefs["focus_period"], (8, 12)
    )
    
    for entry in schedule:
        if entry["type"] == "Break":
            reward += 1  # encourage regular breaks
        else:
            start_time = datetime.strptime(entry["start"], "%Y-%m-%d %H:%M")
            hour = start_time.hour
            in_focus = focus_start <= hour < focus_end
            reward += 2 if in_focus else -1  # focus hour bonus

            # Bonus for scheduling high-priority tasks early
            priority = entry.get("priority", "Low")
            priority_score = {"Low": 1, "Medium": 2, "High": 3, "Extra High": 4}.get(priority, 1)
            reward += priority_score * (24 - hour) / 24  # weight early hours higher

    # Align with preferred work style
    long_chunks = user_prefs["work_style"] == "long_chunks"
    avg_duration = _avg_task_duration(schedule)
    if long_chunks and avg_duration >= 60:
        reward += 3
    elif not long_chunks and avg_duration < 45:
        reward += 3
    else:
        reward -= 2

    # Penalty or bonus based on current stress level
    stress = user_prefs["stress_level"]
    reward += (10 - stress) * 0.5  # lower stress = higher reward
    
    return reward

def _avg_task_duration(schedule):
    durations = []
    for entry in schedule:
        start_val = entry["start"]
        end_val = entry["end"]
        if isinstance(start_val, datetime):
            start = start_val
        else:
            start = datetime.strptime(start_val, "%Y-%m-%d %H:%M")
        if isinstance(end_val, datetime):
            end = end_val
        else:
            end = datetime.strptime(end_val, "%Y-%m-%d %H:%M")
        durations.append((end - start).total_seconds() / 60)
    return sum(durations) / len(durations) if durations else 0
