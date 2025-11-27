import Foundation
import EventKit
import AppKit

class RemindersManager: ObservableObject {
    private let store = EKEventStore()
    
    @Published var isAccessGranted = false
    
    init() {
        requestAccess()
    }
    
    func requestAccess(completion: ((Bool) -> Void)? = nil) {
        store.requestAccess(to: .reminder) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAccessGranted = granted
                if let error = error {
                    print("Error requesting access: \(error.localizedDescription)")
                }
                completion?(granted)
            }
        }
    }
    
    func fetchLists() -> [EKCalendar] {
        guard isAccessGranted else { return [] }
        return store.calendars(for: .reminder)
    }
    
    func fetchReminders(in calendar: EKCalendar? = nil, completion: @escaping ([EKReminder]) -> Void) {
        guard isAccessGranted else {
            completion([])
            return
        }
        
        let calendars = calendar != nil ? [calendar!] : nil
        let predicate = store.predicateForReminders(in: calendars)
        store.fetchReminders(matching: predicate) { reminders in
            DispatchQueue.main.async {
                completion(reminders ?? [])
            }
        }
    }
    
    func addReminder(title: String, in calendar: EKCalendar? = nil, completion: @escaping (EKReminder?) -> Void) {
        guard isAccessGranted else {
            completion(nil)
            return
        }
        
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar ?? store.defaultCalendarForNewReminders()
        
        do {
            try store.save(reminder, commit: true)
            completion(reminder)
        } catch {
            print("Error saving reminder: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    func toggleCompletion(reminder: EKReminder, completion: @escaping (Bool) -> Void) {
        guard isAccessGranted else {
            completion(false)
            return
        }
        
        reminder.isCompleted = !reminder.isCompleted
        
        do {
            try store.save(reminder, commit: true)
            completion(true)
        } catch {
            print("Error toggling completion: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    func toggleCompletion(identifier: String, isCompleted: Bool, completion: @escaping (Bool) -> Void) {
        guard isAccessGranted else {
            completion(false)
            return
        }
        
        if let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            reminder.isCompleted = isCompleted
            do {
                try store.save(reminder, commit: true)
                completion(true)
            } catch {
                print("Error toggling completion: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    func addNewList(title: String, color: NSColor?, completion: @escaping (EKCalendar?) -> Void) {
        guard isAccessGranted else {
            completion(nil)
            return
        }
        
        let newList = EKCalendar(for: .reminder, eventStore: store)
        newList.title = title
        if let color = color {
            newList.cgColor = color.cgColor
        }
        
        // We need to set the source. Use the same source as the default calendar.
        if let defaultCalendar = store.defaultCalendarForNewReminders() {
            newList.source = defaultCalendar.source
        } else {
            // Fallback to the first available source that supports reminders
            newList.source = store.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local })
        }
        
        do {
            try store.saveCalendar(newList, commit: true)
            completion(newList)
        } catch {
            print("Error creating list: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    func moveReminder(identifier: String, to calendar: EKCalendar, completion: @escaping (Bool) -> Void) {
        guard isAccessGranted else {
            completion(false)
            return
        }
        
        if let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            reminder.calendar = calendar
            do {
                try store.save(reminder, commit: true)
                completion(true)
            } catch {
                print("Error moving reminder: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    func deleteList(identifier: String, completion: @escaping (Bool) -> Void) {
        guard isAccessGranted else {
            completion(false)
            return
        }
        
        if let calendar = store.calendar(withIdentifier: identifier) {
            do {
                try store.removeCalendar(calendar, commit: true)
                completion(true)
            } catch {
                print("Error deleting list: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    func deleteReminder(identifier: String, completion: @escaping (Bool) -> Void) {
        guard isAccessGranted else {
            completion(false)
            return
        }
        
        if let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            do {
                try store.remove(reminder, commit: true)
                completion(true)
            } catch {
                print("Error deleting reminder: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    func updateReminder(identifier: String, title: String? = nil, notes: String? = nil, dueDate: Date? = nil, completion: @escaping (Bool) -> Void) {
        guard isAccessGranted else {
            completion(false)
            return
        }
        
        if let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder {
            if let title = title {
                reminder.title = title
            }
            if let notes = notes {
                reminder.notes = notes
            }
            if let dueDate = dueDate {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                reminder.dueDateComponents = components
                // Also update alarms if needed, but for now just due date
            }
            
            do {
                try store.save(reminder, commit: true)
                completion(true)
            } catch {
                print("Error updating reminder: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            completion(false)
        }
    }
}
