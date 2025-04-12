# User Preferences Onboarding Feature

This document explains the implementation of the user preferences onboarding flow and preferences management system in the CookMate AI app.

## Overview

The user preferences feature allows users to customize their recipe recommendations based on their dietary restrictions, health goals, cooking skill level, time constraints, and measurement unit preferences. It includes:

1. A first-time onboarding flow that guides new users through setting their preferences
2. A unified preferences management screen accessible from the profile
3. Individual preference editing screens
4. Persistence of preferences using SharedPreferences

## Implementation Details

### User Profile Model

The `UserProfile` model was extended to include:

- `healthGoals`: A list of health objectives (weight loss, muscle gain, etc.)
- `maxPrepTimeMinutes`: Maximum recipe preparation time the user prefers
- `hasCompletedOnboarding`: A flag to track if onboarding is complete

### Preference Screens

The following screens were created or modified to support user preferences:

1. **DietaryPreferencesScreen**: For dietary restrictions and food allergies
2. **HealthGoalsScreen**: For health and nutrition objectives
3. **CookingSkillLevelScreen**: For cooking experience level
4. **PrepTimePreferencesScreen**: For time constraints
5. **MeasurementUnitsScreen**: For preferred measurement system
6. **UserPreferencesScreen**: A unified preferences dashboard
7. **PreferencesOnboardingScreen**: Multi-step onboarding flow with progress indicator

### Onboarding Flow

The onboarding flow presents preference screens in sequence with:

- A progress bar showing completion status
- Skip/Next options for each section
- A completion action that marks onboarding as done

The app router was configured to automatically direct new users to the onboarding flow until it's completed.

### Data Persistence

All preferences are stored using SharedPreferences through the `UserProfileNotifier` class, which provides methods for:

- Loading preferences on app start
- Saving updated preferences
- Checking if onboarding is needed

## User Experience

1. First-time users see the onboarding flow with progressive screens
2. Returning users who completed onboarding go directly to the home screen
3. Users can access and modify all preferences from their profile
4. Recipe recommendations are filtered and presented based on user preferences

## Design Considerations

- Each preference screen works in both standalone and onboarding contexts
- Visual cues help users understand their progress during onboarding
- Preferences are grouped logically by category
- All preferences can be modified later from the profile section
