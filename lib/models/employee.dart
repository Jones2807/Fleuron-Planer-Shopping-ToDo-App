import 'package:flutter/material.dart';

/// Represents a team member (person or profile) in the application.
///
/// This class stores the basic information of an employee, such as
/// their [name] and their assigned [color] for visual representation.
class Employee {
  // --- Serialization Keys (Clean Architecture) ---
  static const String keyName = 'name';
  static const String keyColor = 'color';

  /// The full name or display name of the employee.
  final String name;

  /// The color associated with this employee, used for UI elements.
  final Color color;

  /// Creates a new instance of [Employee].
  const Employee(this.name, this.color);

  /// Returns the initials of the employee's name.
  ///
  /// Extracts up to the first two characters of the [name] and converts
  /// them to uppercase. If the name is shorter than two characters,
  /// it returns the entire name in uppercase.
  String get initials => name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();

  /// Converts the [Employee] instance into a JSON-compatible Map.
  ///
  /// The color is stored as a 32-bit ARGB integer value.
  Map<String, dynamic> toJson() => {
    keyName: name,
    keyColor: color.toARGB32(),
  };

  /// Creates an [Employee] instance from a JSON map.
  ///
  /// Expects the map to contain [keyName] and [keyColor], where the color
  /// should be a 32-bit ARGB integer.
  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    json[keyName],
    Color(json[keyColor]),
  );
}
