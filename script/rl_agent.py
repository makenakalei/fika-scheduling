import numpy as np

class SchedulerAgent:
    def __init__(self, action_space):
        self.q_table = {}  # for basic Q-learning
        self.action_space = action_space
        self.learning_rate = 0.1
        self.discount_factor = 0.95
        self.epsilon = 0.1

    def get_state_key(self, state):
        # Convert dict state to a hashable key (e.g., tuple or string)
        return str(state)

    def select_action(self, state):
        key = self.get_state_key(state)
        if key not in self.q_table or np.random.rand() < self.epsilon:
            return np.random.choice(self.action_space)
        return max(self.q_table[key], key=self.q_table[key].get)

    def update(self, state, action, reward, next_state):
        key = self.get_state_key(state)
        next_key = self.get_state_key(next_state)

        if key not in self.q_table:
            self.q_table[key] = {a: 0 for a in self.action_space}
        if next_key not in self.q_table:
            self.q_table[next_key] = {a: 0 for a in self.action_space}

        old_value = self.q_table[key][action]
        next_max = max(self.q_table[next_key].values())

        new_value = (1 - self.learning_rate) * old_value + self.learning_rate * (reward + self.discount_factor * next_max)
        self.q_table[key][action] = new_value
