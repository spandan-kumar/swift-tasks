import Foundation
import EventKit
import AppKit

// We can keep TodoItem as a view model, or just use EKReminder directly.
// Using a struct wrapper is safer for SwiftUI updates.
struct TodoItem: Identifiable {
    let id: String // EKReminder.calendarItemIdentifier
    var title: String
    var isCompleted: Bool
    var date: Date
    var calendarId: String
    var priority: Int // 0 = None, 1 = Low, 5 = Medium, 9 = High (EKReminder priorities)
    var notes: String?
}

class TodoStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var lists: [EKCalendar] = []
    // selectedList removed as we show all
    
    private let remindersManager = RemindersManager()
    
    var isAccessGranted: Bool {
        remindersManager.isAccessGranted
    }
    
    init() {
        remindersManager.requestAccess { [weak self] granted in
            if granted {
                self?.refresh()
            }
        }
        
        // Observe changes from external sources (Reminders app)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func storeChanged() {
        refresh()
    }
    
    func refresh() {
        // Always fetch all reminders
        remindersManager.fetchReminders(in: nil) { [weak self] ekReminders in
            let items = ekReminders.map { rem in
                let date = rem.dueDateComponents?.date ?? rem.creationDate ?? Date()
                return TodoItem(
                    id: rem.calendarItemIdentifier,
                    title: rem.title,
                    isCompleted: rem.isCompleted,
                    date: date,
                    calendarId: rem.calendar.calendarIdentifier,
                    priority: rem.priority,
                    notes: rem.notes
                )
            }
            // Sort by date desc
            self?.todos = items.sorted { $0.date > $1.date }
            
            // Also refresh lists in case they changed
            if let self = self {
                self.lists = self.remindersManager.fetchLists()
            }
        }
    }
    
    func addTodo(title: String, in calendar: EKCalendar?) {
        remindersManager.addReminder(title: title, in: calendar) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func toggleCompletion(for todo: TodoItem) {
        remindersManager.toggleCompletion(identifier: todo.id, isCompleted: !todo.isCompleted) { [weak self] success in
            if success {
                self?.refresh()
            }
        }
    }
    
    func deleteTodo(id: String) {
        remindersManager.deleteReminder(identifier: id) { [weak self] success in
            if success {
                self?.refresh()
            }
        }
    }
    
    func moveTodo(id: String, toListId: String) {
        if let calendar = lists.first(where: { $0.calendarIdentifier == toListId }) {
            remindersManager.moveReminder(identifier: id, to: calendar) { [weak self] success in
                if success {
                    self?.refresh()
                }
            }
        }
    }
    
    func deleteList(id: String) {
        remindersManager.deleteList(identifier: id) { [weak self] success in
            if success {
                self?.refresh()
            }
        }
    }
    
    func addNewList(title: String, color: NSColor?) {
        remindersManager.addNewList(title: title, color: color) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func updateTodo(id: String, title: String? = nil, notes: String? = nil, dueDate: Date? = nil) {
        remindersManager.updateReminder(identifier: id, title: title, notes: notes, dueDate: dueDate) { [weak self] success in
            if success {
                self?.refresh()
            }
        }
    }
    
    // Helper for sections: Group by List
    var groupedLists: [(calendar: EKCalendar, todos: [TodoItem])] {
        var groups: [(EKCalendar, [TodoItem])] = []
        
        for list in lists {
            let listTodos = todos.filter { $0.calendarId == list.calendarIdentifier }
            groups.append((list, listTodos))
        }
        return groups
    }
    
    var todayTodos: [TodoItem] {
        let calendar = Calendar.current
        return todos.filter {
            calendar.isDateInToday($0.date) && !$0.isCompleted
        }
    }
}
