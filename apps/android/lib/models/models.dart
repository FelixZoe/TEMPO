import 'package:flutter/material.dart';

class ScheduleEvent {
  final String id;
  final String title;
  final String description;
  final String time;
  final String endTime;
  final String category;
  final Color accentColor;
  final bool isCompleted;

  ScheduleEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.time,
    this.endTime = '',
    this.category = '工作',
    required this.accentColor,
    this.isCompleted = false,
  });

  ScheduleEvent copyWith({bool? isCompleted}) {
    return ScheduleEvent(
      id: id,
      title: title,
      description: description,
      time: time,
      endTime: endTime,
      category: category,
      accentColor: accentColor,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class TaskItem {
  final String id;
  final String title;
  final bool isCompleted;
  final int priority; // 0=low, 1=medium, 2=high

  TaskItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.priority = 1,
  });

  TaskItem copyWith({bool? isCompleted}) {
    return TaskItem(
      id: id,
      title: title,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority,
    );
  }
}

class GoalItem {
  final String id;
  final String title;
  final String icon;
  final double progress;
  final Color color;
  final String target;

  GoalItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.progress,
    required this.color,
    required this.target,
  });
}

class HabitItem {
  final String id;
  final String title;
  final String icon;
  final int streak;
  final Color color;
  final bool todayCompleted;

  HabitItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.streak,
    required this.color,
    this.todayCompleted = false,
  });

  HabitItem copyWith({bool? todayCompleted, int? streak}) {
    return HabitItem(
      id: id,
      title: title,
      icon: icon,
      streak: streak ?? this.streak,
      color: color,
      todayCompleted: todayCompleted ?? this.todayCompleted,
    );
  }
}

class FileItem {
  final String id;
  final String name;
  final String type; // note, doc, image, folder
  final String size;
  final String date;
  final bool isFavorite;

  FileItem({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.date,
    this.isFavorite = false,
  });
}

class NoteItem {
  final String id;
  final String title;
  final String content;
  final String date;
  final Color color;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.color,
  });
}
