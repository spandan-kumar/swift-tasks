#!/bin/bash

APP_NAME="MenuBarTodo"
ZIP_NAME="MenuBarTodo.zip"

# 1. Build the app
echo "Building App..."
./build.sh

# 2. Create README
echo "Creating README..."
cat > README.txt <<EOF
MenuBar Todo App
================

Installation:
1. Drag 'MenuBarTodo.app' to your Applications folder.
2. Double-click to open.

Troubleshooting:
If macOS says the app "cannot be opened because it is from an unidentified developer":
1. Right-click (or Control-click) on the app.
2. Select "Open" from the menu.
3. Click "Open" in the dialog box.

Features:
- Cmd+Shift+T to toggle the app.
- Drag and drop tasks to organize.
- Double-click tasks to rename or add notes.
EOF

# 3. Zip it up
echo "Zipping..."
rm -f $ZIP_NAME
zip -r $ZIP_NAME $APP_NAME.app README.txt

echo "Done! Ready to share: $ZIP_NAME"
