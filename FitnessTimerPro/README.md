# Fitness Timer Pro (iOS Version)

Here is the iOS native implementation of the Fitness Timer Pro app, built with purely **SwiftUI** to match user requirements.

## How to Run

1.  **Open Xcode** and select **Create a new Xcode project**.
2.  Choose **App** under the iOS tab.
3.  Set the Product Name to `FitnessTimerPro`.
4.  Ensure **Interface** is set to **SwiftUI** and **Language** to **Swift**.
5.  Once the project is created, locate the folder where you saved the project in Finder.
6.  **Replace** the default files or **Add** the provided files into your Xcode project's folder structure.
    - Copy the contents of the `FitnessTimerPro` directory provided here into your project's main group.
    - Important: Ensure `FitnessTimerProApp.swift` is your main entry point (using `@main`).
7.  **Build and Run** on an iOS Simulator (e.g., iPhone 15 Pro).

## Project Structure

- **FitnessTimerProApp.swift**: The application entry point.
- **Models.swift**: core data structures (`Exercise`, `WorkoutState`).
- **Utils.swift**: Color extensions and helpers.
- **ViewModels/WorkoutManager.swift**: Central state management logic (Timer, Workout Progress, Calendar Data).
- **Views/**:
    - **ContentView.swift**: Main container with the custom bottom navigation bar.
    - **CalendarView.swift**: The Plan tab with a horizontal date strip and exercise list.
    - **TimerView.swift**: The Timer tab with the large display and status-changing background.
    - **AddExerciseView.swift**: The modal form for adding/editing exercises.

## Features

- **Dark Mode UI**: Pure black/dark gray theme matching the web version.
- **Calendar Logic**: Horizontal date scrolling, selecting days, and viewing history.
- **Timer & Workout Logic**:
    - **Free Training mode** vs **Planned Exercise mode**.
    - **Timer States**: Prepare (Orange) -> Work (Green) -> Rest (Blue).
    - **Infinite Timer**: Support for unlimited training durations.
- **Interactive UI**:
    - Custom Tab Bar.
    - Swipe actions (standard list) or tap-to-start.
    - Edit modals.
