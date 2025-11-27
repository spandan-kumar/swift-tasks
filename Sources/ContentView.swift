import SwiftUI
import EventKit
import AppKit

struct ContentView: View {
    @StateObject private var store = TodoStore()
    @State private var newTodoTitle = ""
    
    // Date formatter for section headers
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true // "Today", "Yesterday"
        return formatter
    }()
    
    @State private var showNewListPopover = false
    @State private var newListTitle = ""
    @State private var newListColor = Color.blue
    @State private var targetList: EKCalendar?
    
    @AppStorage("hideChecked") private var hideChecked = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var selectedTaskId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tasks")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                // New List Button
                Button(action: {
                    showNewListPopover.toggle()
                }) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showNewListPopover) {
                    VStack(spacing: 12) {
                        Text("New List")
                            .font(.headline)
                        
                        TextField("List Name", text: $newListTitle)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        
                        ColorPicker("List Color", selection: $newListColor)
                            .labelsHidden()
                        
                        Button("Create") {
                            createNewList()
                        }
                        .disabled(newListTitle.isEmpty)
                    }
                    .padding()
                }
                .help("Create New List")
                
                // Settings Menu
                Menu {
                    Toggle("Show Completed", isOn: Binding(
                        get: { !hideChecked },
                        set: { _ in
                            withAnimation {
                                hideChecked.toggle()
                            }
                        }
                    ))
                    
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            MenuBarManager().setLaunchAtLogin(enabled: newValue)
                        }
                    ))
                    
                    Divider()
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16, height: 16)
                .help("Settings")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            if !store.isAccessGranted {
                AccessDeniedView()
            } else {
                ScrollViewReader { proxy in
                    List {
                        // Today Section
                        if !store.todayTodos.isEmpty {
                            Section(header: Text("TODAY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                            ) {
                                ForEach(store.todayTodos) { todo in
                                    TodoRow(todo: todo, store: store, isSelected: selectedTaskId == todo.id)
                                        .id(todo.id)
                                        .onDrag {
                                            NSItemProvider(object: todo.id as NSString)
                                        }
                                        .onTapGesture {
                                            selectedTaskId = todo.id
                                        }
                                        .animation(.default, value: todo.isCompleted)
                                }
                            }
                        }
                        
                        ForEach(store.groupedLists, id: \.calendar.calendarIdentifier) { group in
                            // Filter todos based on hideChecked
                            let visibleTodos = group.todos.filter { !hideChecked || !$0.isCompleted }
                            
                            // Only show section if there are visible todos or if we are not hiding checked items (so we can see empty state)
                            // Actually, if hideChecked is true and all are completed, we should probably hide the section or show empty?
                            // Simplest: Show section if visibleTodos is not empty, OR if group.todos is empty (true empty state)
                            if !visibleTodos.isEmpty || group.todos.isEmpty {
                                Section(header: ListSectionHeader(calendar: group.calendar, onAdd: {
                                    targetList = group.calendar
                                }, onDelete: {
                                    store.deleteList(id: group.calendar.calendarIdentifier)
                                })) {
                                    if group.todos.isEmpty {
                                        Text("All items completed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 24) // Indent to align with text
                                            .listRowBackground(Color.clear)
                                            .onDrop(of: [.text], isTargeted: nil) { providers in
                                                dropTask(providers: providers, to: group.calendar)
                                            }
                                    } else {
                                        ForEach(visibleTodos) { todo in
                                            TodoRow(todo: todo, store: store, isSelected: selectedTaskId == todo.id)
                                                .id(todo.id) // For ScrollViewReader
                                                .onDrag {
                                                    NSItemProvider(object: todo.id as NSString)
                                                }
                                                .onTapGesture {
                                                    selectedTaskId = todo.id
                                                }
                                                .animation(.default, value: todo.isCompleted)
                                        }
                                    }
                                }
                                .onDrop(of: [.text], isTargeted: nil) { providers in
                                    dropTask(providers: providers, to: group.calendar)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .onAppear {
                        setupKeyboardHandling()
                    }
                }
            }
            
            Divider()
            
            // Add New
            HStack {
                TextField(targetList != nil ? "Add to \(targetList!.title)..." : "Add a new task...", text: $newTodoTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        addTodo()
                    }
                
                if targetList != nil {
                    Button(action: { targetList = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: addTodo) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(newTodoTitle.isEmpty ? .secondary : .blue)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 320, height: 500)
    }
    
    private func setupKeyboardHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check if a text field is currently being edited
            if let window = NSApp.keyWindow,
               let firstResponder = window.firstResponder as? NSTextView {
                // If we are editing text, do not intercept keys
                return event
            }
            
            switch event.keyCode {
            case 126: // Arrow Up
                moveSelection(direction: -1)
                return nil
            case 125: // Arrow Down
                moveSelection(direction: 1)
                return nil
            case 49: // Space
                if let id = selectedTaskId {
                    toggleCompletion(id: id)
                    return nil
                }
            default:
                break
            }
            return event
        }
    }
    
    private func moveSelection(direction: Int) {
        // Flatten visible todos
        let allVisibleTodos = store.groupedLists.flatMap { group in
            group.todos.filter { !hideChecked || !$0.isCompleted }
        }
        
        guard !allVisibleTodos.isEmpty else { return }
        
        if let currentId = selectedTaskId, let index = allVisibleTodos.firstIndex(where: { $0.id == currentId }) {
            let newIndex = max(0, min(allVisibleTodos.count - 1, index + direction))
            selectedTaskId = allVisibleTodos[newIndex].id
        } else {
            selectedTaskId = allVisibleTodos.first?.id
        }
    }
    
    private func toggleCompletion(id: String) {
        // Find todo item
        for group in store.groupedLists {
            if let todo = group.todos.first(where: { $0.id == id }) {
                store.toggleCompletion(for: todo)
                break
            }
        }
    }
    
    private func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        // Add to targeted list or default
        store.addTodo(title: title, in: targetList)
        newTodoTitle = ""
        // Keep target list selected for rapid entry, or clear it? User didn't specify.
        // Let's keep it for now.
    }
    
    private func createNewList() {
        store.addNewList(title: newListTitle, color: NSColor(newListColor))
        newListTitle = ""
        showNewListPopover = false
    }
    
    private func dropTask(providers: [NSItemProvider], to calendar: EKCalendar) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            if let data = data as? Data, let id = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    store.moveTodo(id: id, toListId: calendar.calendarIdentifier)
                }
            } else if let id = data as? String {
                 DispatchQueue.main.async {
                    store.moveTodo(id: id, toListId: calendar.calendarIdentifier)
                }
            }
        }
        return true
    }
}

struct ListSectionHeader: View {
    let calendar: EKCalendar
    let onAdd: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        HStack {
            Text(calendar.title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
        .contextMenu {
            Button("Delete List") {
                showDeleteAlert = true
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete List"),
                message: Text("Are you sure you want to delete '\(calendar.title)'? This will also delete all tasks in it."),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct TodoRow: View {
    let todo: TodoItem
    @ObservedObject var store: TodoStore
    let isSelected: Bool
    @State private var isHovering = false
    
    // Editing states
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showNotesPopover = false
    @State private var editedNotes = ""
    @State private var showDatePicker = false
    @State private var newDate = Date()
    
    // Date formatter for due date
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top) {
            Toggle(isOn: Binding(
                get: { todo.isCompleted },
                set: { _ in store.toggleCompletion(for: todo) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    if isEditingTitle {
                        TextField("Title", text: $editedTitle, onCommit: {
                            store.updateTodo(id: todo.id, title: editedTitle)
                            isEditingTitle = false
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    } else {
                        Text(todo.title)
                            .strikethrough(todo.isCompleted)
                            .foregroundColor(todo.isCompleted ? .secondary : .primary)
                            .font(.system(size: 13))
                            .onTapGesture(count: 2) {
                                editedTitle = todo.title
                                isEditingTitle = true
                            }
                    }
                    
                    if !todo.isCompleted {
                        HStack(spacing: 6) {
                            // Due Date
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(dateFormatter.string(from: todo.date))
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                newDate = todo.date
                                showDatePicker = true
                            }
                            .popover(isPresented: $showDatePicker) {
                                VStack {
                                    DatePicker("Due Date", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.graphical)
                                        .labelsHidden()
                                    
                                    Button("Save") {
                                        store.updateTodo(id: todo.id, dueDate: newDate)
                                        showDatePicker = false
                                    }
                                }
                                .padding()
                            }
                            
                            // Notes Indicator
                            if let notes = todo.notes, !notes.isEmpty {
                                Image(systemName: "note.text")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        editedNotes = notes
                                        showNotesPopover = true
                                    }
                            }
                        }
                    }
                }
            }
            .toggleStyle(.checkbox)
            
            Spacer()
            
            if isHovering || isSelected {
                HStack(spacing: 8) {
                    // Notes Button
                    Button(action: {
                        editedNotes = todo.notes ?? ""
                        showNotesPopover = true
                    }) {
                        Image(systemName: "note.text.badge.plus")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showNotesPopover) {
                        VStack(spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            TextEditor(text: $editedNotes)
                                .frame(width: 200, height: 100)
                                .font(.system(size: 12))
                                .border(Color.secondary.opacity(0.2))
                            
                            Button("Save") {
                                store.updateTodo(id: todo.id, notes: editedNotes)
                                showNotesPopover = false
                            }
                        }
                        .padding()
                    }
                    
                    // Delete Button
                    Button(action: {
                        store.deleteTodo(id: todo.id)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No tasks yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add a task to get started")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.5))
            Text("Access Denied")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Please allow access to Reminders in System Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                    NSWorkspace.shared.open(url)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}
