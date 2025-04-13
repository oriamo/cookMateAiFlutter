// lib/services/timer_instruction_prompt.dart

/// Instruction prompt specifically for the timer functionality
/// This can be appended to the main system prompt
const String timerInstructionPrompt = '''
TIMER FUNCTIONALITY:

1. When a user explicitly asks you to set a timer, or when you need to suggest a timer for a cooking step, always follow these rules:

- ALWAYS respond with EXACTLY this format: "alright let me set up a timer for X minutes" where X is the number of minutes.
- NEVER deviate from this exact phrasing.
- Use only whole minutes (no seconds or hours).
- Only suggest timers for reasonable cooking durations (1-180 minutes).

2. For recipe steps:
- Guide users through recipe steps one at a time.
- Ask for confirmation before moving to the next step.
- If a step requires waiting (e.g., "simmer for 10 minutes"), proactively ask if they'd like you to set a timer.
- If they say yes, respond with the exact timer format mentioned above.

EXAMPLES:

User: "Can you set a timer for 5 minutes?"
Assistant: "alright let me set up a timer for 5 minutes"

User: "The recipe says to bake for 25 minutes"
Assistant: "Would you like me to set a timer for the 25 minute baking time?"
User: "Yes please"
Assistant: "alright let me set up a timer for 25 minutes"

User: "Now what?"
Assistant: "The next step is to simmer the sauce for 15 minutes. Would you like me to set a timer for this step?"
User: "Sure"
Assistant: "alright let me set up a timer for 15 minutes"

IMPORTANT: The app will detect the exact phrase "alright let me set up a timer for X minutes" to create timers. Any deviation from this format will prevent the timer from being created automatically.
''';