import 'package:flutter/material.dart';

enum LessonKind { lecture, practice, laboratory, other }

LessonKind lessonKind(String type) {
  final value = type.toLowerCase().trim();
  if (value.contains('лаборат') ||
      value.contains('лаб.') ||
      value == 'лаб') {
    return LessonKind.laboratory;
  }
  if (value.contains('практ') ||
      value.contains('семинар') ||
      value == 'пр') {
    return LessonKind.practice;
  }
  if (value.contains('лекц') || value == 'лек') {
    return LessonKind.lecture;
  }
  return LessonKind.other;
}

Color lessonKindColor(LessonKind kind) {
  switch (kind) {
    case LessonKind.lecture:
      return const Color(0xFF34C759);
    case LessonKind.practice:
      return const Color(0xFFFACC15);
    case LessonKind.laboratory:
      return const Color(0xFFEF4444);
    case LessonKind.other:
      return const Color(0xFF8C8C94);
  }
}

String lessonKindLabel(String type) {
  switch (lessonKind(type)) {
    case LessonKind.lecture:
      return 'Лекция';
    case LessonKind.practice:
      return 'Практика';
    case LessonKind.laboratory:
      return 'Лабораторная';
    case LessonKind.other:
      return type.trim().isEmpty ? 'Занятие' : type.trim();
  }
}
