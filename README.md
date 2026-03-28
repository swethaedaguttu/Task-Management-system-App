# Task Management System (Track A)

This repository contains a Flutter + Python (FastAPI) Task Management App.

## Features implemented (per requirements)

- Task model fields:
  - `Title` (text)
  - `Description` (text)
  - `Due Date` (date, `YYYY-MM-DD`)
  - `Status` (`To-Do`, `In Progress`, `Done`)
  - `Blocked By` (optional dropdown referencing another existing task; stored as `blocked_by_id` in DB)
- Main List View
  - Search by **`Title` and `Description`** (server-side via REST `GET /tasks?q=...`, case-insensitive match on both fields, **debounced 300ms** after typing stops)
  - Matching text is **highlighted** in task titles in the list (description matches are not highlighted)
  - Filter by `Status` (server-side via REST `GET /tasks?status=...`)
  - Pull-to-refresh on the task list
  - If a task is blocked by another task that is not `Done`, its card is visually greyed out and shows the blocker’s title (`Blocked by: …`)
- Task Creation/Edit
  - Create + Edit screen with all required fields
  - Draft persistence for *create*: typed text remains after accidentally navigating away, **minimizing the app**, and returning
- CRUD
  - Create, Read, Update, Delete tasks
- Track A delay behavior
  - Backend simulates a 2-second delay on all Task Creations and Updates
  - Frontend shows a loading state and disables the `Save` button to prevent double-taps

- Backend robustness
  - `blocked_by_id` uses `ON DELETE SET NULL` so deleting a blocker task does not break SQLite foreign keys
  - SQLite runs with `PRAGMA foreign_keys=ON`
  - `GET /` health-style JSON for quick checks

## Track selection

- Track A: Full-Stack Builder (Flutter + FastAPI + SQLite)
- Stretch goal: Not implemented

## Setup (Backend)

1. Open a terminal:
   - `cd "c:\Task Management System app\backend"`
2. Create and activate a Python virtual environment:
   - Windows (PowerShell):
     - `python -m venv .venv`
     - `.venv\Scripts\Activate.ps1`
3. Install dependencies:
   - `pip install -r requirements.txt`
4. Start the API:
   - `uvicorn main:app --reload --port 8000`

## Setup (Frontend)

1. Open a terminal:
   - `cd "c:\Task Management System app\frontend"`
2. Ensure you have a Flutter SDK installed and that your Flutter project scaffold exists under `frontend/` (Android/iOS directories).
   - If your scaffold is missing, create a Flutter app in `frontend/` (or copy these `lib/` + `pubspec.yaml` into an app scaffold) so `flutter run` works.
3. Install dependencies:
   - `flutter pub get`
4. Run:
   - `flutter run`

### API Base URL

The Flutter app picks a default base URL automatically:
- **Android emulator**: `http://10.0.2.2:8000` (host machine loopback)
- **Other platforms (incl. iOS simulator / desktop / web dev)**: `http://localhost:8000`

Override anytime:
- `flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000` (common for a **physical Android device**)

### SQLite migration note

If you created `tasks.db` before `ON DELETE SET NULL` was added, delete `backend/tasks.db` once and restart the API so the schema is recreated cleanly.

### Troubleshooting (Android emulator)

- **HTTP to `http://10.0.2.2:8000` blocked / tasks never load**: the app enables **`android:usesCleartextTraffic="true"`** and **`INTERNET`** in `android/app/src/main/AndroidManifest.xml`. After changing the manifest, do a **full restart** (`flutter run` again), not only hot reload.
- **`Device emulator-5554 is offline`**: the AVD is in a bad state or ADB is stale.
  - Close the emulator, then:  
    `"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" kill-server`  
    `"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" start-server`  
  - Start the AVD again (Android Studio **Cold Boot** or `flutter emulators --launch <id>`).
- **`Skipped … frames` / `Davey!` in logcat**: common on **first cold start** of a debug build on an emulator (JIT, Impeller, slow GPU). Not necessarily an app bug.
  - Try `flutter run --release` for a smoother demo, or run on **Windows** / **Chrome** with `flutter run -d windows` / `-d chrome`.

## AI Usage Report (template)

- Prompt(s) used:
  - “Design a FastAPI + SQLAlchemy schema for tasks with blocked_by_id referencing tasks.”
  - “Implement Flutter UI with drafts stored in SharedPreferences and async save button disabling during loading.”
- Known issue example (if applicable):
  - If an AI suggestion introduces an incorrect field name/type or enum value, it should be corrected to match the backend and required UI labels.

