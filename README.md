# Swift Tasks (MenuBarTodo)

A native macOS menu bar application for managing tasks, integrated seamlessly with Apple Reminders.

## Features

- **Menu Bar Access**: Always available with a global hotkey (`Cmd+Shift+T`).
- **Apple Reminders Sync**: Two-way sync with your iCloud Reminders.
- **Smart Views**: "Today" view for focused work.
- **Task Management**:
  - Create, edit, and delete tasks.
  - Organize tasks into custom lists (categories).
  - Drag and drop tasks between lists.
  - Set due dates and add notes.
- **Productivity**:
  - Keyboard navigation (Arrow keys, Space to complete).
  - Hide completed items.
  - "Launch at Login" support.

## Installation

### From Source
1. Clone the repository.
2. Run `./build.sh` to compile the app.
3. The app will be created as `MenuBarTodo.app`.
4. Drag it to your Applications folder.

### Pre-built
(If you have a release zip)
1. Unzip `MenuBarTodo.zip`.
2. Drag `MenuBarTodo.app` to your Applications folder.

## Development

- **Language**: Swift 5
- **Frameworks**: SwiftUI, AppKit, EventKit, Carbon
- **Build System**: Custom shell script (`build.sh`) avoiding heavy Xcode project files for simplicity.

## License

MIT
