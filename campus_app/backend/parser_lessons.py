from imports import *

class Lessons:
    def __init__(self, date: str = None, start_time : str = None, end_time: str = None,\
                 lesson_type: str = None, subject: str = None, room: str = None, teacher_name: str = None, rank_teacher: str = None):
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.lesson_type = lesson_type
        self.subject = subject
        self.room = room
        self.teacher_name = teacher_name
        self.rank_teacher = rank_teacher

    def to_dict(self):
        """
        Преобразование в словарь
        """
        return {
            "date": self.date,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "lesson_type": self.lesson_type,
            "subject": self.subject,
            "room": self.room,
            "teacher_name": self.teacher_name,
            "rank_teacher": self.rank_teacher

        }
