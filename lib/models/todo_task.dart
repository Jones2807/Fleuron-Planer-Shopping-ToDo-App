// ==========================================
// DATA MODELS
// ==========================================

/// Represents a single to-do task or action item in the application.
///
/// This model holds the state and details of a task, including its
/// completion status, optional description, and deadline.
class TodoTask {
  /// The unique identifier of the task (e.g., a UUID).
  final String uid;

  /// The main title or short name of the task.
  final String title;

  /// An optional detailed description providing more context about the task.
  final String? description;

  /// An optional deadline or scheduled date for when the task should be completed.
  final DateTime? dueDate;

  /// Indicates whether the task has been completed (`true`) or is still pending (`false`).
  bool isDone;

  /// Creates a new instance of [TodoTask].
  TodoTask({
    required this.uid,
    required this.title,
    this.isDone = false,
    this.description,
    this.dueDate,
  });
}
