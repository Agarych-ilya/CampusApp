from imports import *

class Lessons:
    def __init__(self, 
                 subject: str,  
                 date: str = None, 
                 start_time : str = None, 
                 end_time: str = None,
                 lesson_type: str = None, 
                 room: str = None, 
                 location: str = None, 
                 teacher_name: str = None, 
                 rank_teacher: str = None
                 ):
        self.subject = subject
        self.date = date
        self.start_time = start_time
        self.end_time = end_time
        self.lesson_type = lesson_type
        self.room = room
        self.location = location
        self.teacher_name = teacher_name
        self.rank_teacher = rank_teacher

    def to_dict(self):
        """
        Преобразование в словарь
        """
        return {
            "subject": self.subject,
            "date": self.date,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "lesson_type": self.lesson_type,
            "room": self.room,
            "location": self.location,
            "teacher_name": self.teacher_name,
            "rank_teacher": self.rank_teacher

        }
