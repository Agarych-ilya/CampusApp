from database_universities_imports import *

class UniversityDatabase:
    def __init__(self, db_path = "universities.db"):
        """
        Инициализируем базы данных для университетов
        """
        self.db_path = db_path
        self._connection = sqlite3.connect(self.db_path)
        self.cursor = self._connection.cursor()
        self.create_tables()



    def close(self):
        """
        Закрытие соединения
        """
        if self._connection:
          self._connection.commit()
          self._connection.close()
          self._connection = None
          print("=" * 60)
          print("Соединение закрыто")

    def create_tables(self):
        """
        Создание таблиц университетов и факультетов
        """
        cursor = self.cursor

        # 1. ОСНОВНАЯ таблица университетов (с маленькой буквы!)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS universities 
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                city TEXT NOT NULL,
                schedule_url TEXT NOT NULL,
                full_name_university TEXT UNIQUE,
                official_website TEXT,
                schedule_type TEXT DEFAULT 'html'
            )
        ''')

        # 2. Таблица факультетов
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS faculties 
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                university_name TEXT NOT NULL,
                name_faculty TEXT NOT NULL,
                full_name_faculty TEXT,
                faculty_url TEXT,
                faculty_schedule_url TEXT,
                FOREIGN KEY (university_name) REFERENCES universities(name) ON DELETE CASCADE,
                UNIQUE(university_name, name_faculty)
            )
        ''')

        # 3. Конфиги парсеров
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS parser_configs 
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                university_name TEXT UNIQUE NOT NULL,
                config_json TEXT NOT NULL,
                FOREIGN KEY (university_name) REFERENCES universities(name) ON DELETE CASCADE
            )
        ''')

        # 4. Статистика вуза
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS university_statistics 
            (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                university_name TEXT UNIQUE NOT NULL,
                number_of_faculties INTEGER DEFAULT 0,
                number_of_students INTEGER DEFAULT 0,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (university_name) REFERENCES universities(name) ON DELETE CASCADE
            )
        ''')

        self._connection.commit()
        print("✅ Таблицы созданы")

    def add_university(self,
                       name: str,
                       city: str,
                       schedule_url: str,
                       official_website: str = None,
                       full_name_university: str = None,
                       schedule_type: str = None) -> int:
        """
        Добавление нового университета


        Args:
            name: Короткое название (МГУ, МФТИ)
            city: Город
            schedule_url: URL расписания
            official_website: Официальный сайт
            full_name_university: Полное название
            schedule_type: Тип расписания (html, api, pdf)

        Returns:
            int: ID университета или -1 при ошибке
        """
        try:
            if full_name_university is None:
                full_name_university = name
            self.cursor.execute('''
                INSERT INTO universities 
                (name, city, schedule_url, official_website, full_name_university, schedule_type)
                VALUES (?, ?, ?, ?, ?, ?)
                ''', (name, city, schedule_url, official_website, full_name_university, schedule_type))

            university_id = self.cursor.lastrowid # Только для return(проверка работы метода)

            self.cursor.execute('''
            INSERT INTO university_statistics (university_name)
            VALUES (?)
            ''', (name,))

            self._connection.commit()
            print(f"✅ Университет добавлен: {name} (ID: {university_id})")
            return university_id

        except sqlite3.IntegrityError as e:
            if "UNIQUE" in str(e):
                print(f"⚠️ Университет '{name}' уже существует")
            else:
                print(f"❌ Ошибка целостности: {e}")
            return -1
        except Exception as e:
            print(f"❌ Ошибка при добавлении университета: {e}")
            self._connection.rollback()
            return -1


    def add_faculty(self,
                    university_name: str,
                    name_faculty: str,
                    full_name_faculty: str = None,
                    faculty_url: str = None,
                    faculty_schedule_url: str = None) -> int:
        """
        Добавление факультета к университету

        Args:
        university_name: Название университета (МГУ, МФТИ)
        name_faculty: Название факультета
        full_name_faculty: Полное название факультета
        faculty_url: URL факультета
        faculty_schedule_url: URL расписания факультета

         Returns:
            int: ID факультета или -1 при ошибке
        """
        try:
            self.cursor.execute('SELECT name FROM universities WHERE name=?', (university_name,))
            if not self.cursor.fetchone():
               print(f"❌ Университет '{university_name}' не найден")
               return -1
            if full_name_faculty is None:
                full_name_faculty = name_faculty

            self.cursor.execute('''
            INSERT INTO faculties
            (university_name, name_faculty, full_name_faculty, faculty_url, faculty_schedule_url)
            VALUES (?, ?, ?, ?, ?)
            ''',(university_name, name_faculty, full_name_faculty, faculty_url, faculty_schedule_url))

            faculty_id = self.cursor.lastrowid

            self._connection.commit()
            print(f"✅ Факультет добавлен: {university_name} → {name_faculty} (ID: {faculty_id})")
            return faculty_id
        except sqlite3.IntegrityError as e:
            if "UNIQUE" in str(e):
                print(f"⚠️ Факультет '{name_faculty}' уже существует в '{university_name}'")
            elif "FOREIGN KEY" in str(e):
                print(f"❌ Университет '{university_name}' не найден")
            else:
                print(f"❌ Ошибка целостности: {e}")
            return -1
        except Exception as e:
            print(f"❌ Ошибка при добавлении факультета: {e}")
            self._connection.rollback()
            return -1

    def add_parser_config(self,
                          university_name: str,
                          config: dict) -> int:
            """
            Добавление конфигурации парсера для университета

            Args:
            niversity_name: Название университета
            config: Словарь с конфигурацией

            Returns:
            int: ID конфига или -1 при ошибке
            """

            try:
                config_json = json.dumps(config, ensure_ascii=False)

                self.cursor.execute('''
                INSERT INTO parser_configs (university_name, config_json)
                VALUES (?, ?)
                ''', (university_name, config_json))

                config_id = self.cursor.lastrowid
                self._connection.commit()

                print(f"✅ Конфиг парсера добавлен для: {university_name}")
                return config_id

            except sqlite3.IntegrityError as e:
                if "UNIQUE" in str(e):
                    print(f"✅ Конфиг парсера добавлен для: {university_name}")
                elif "FOREIGN KEY" in str(e):
                    print(f"❌ Университет '{university_name}' не найден")
                else:
                    print(f"❌ Ошибка: {e}")
                return -1
            except Exception as e:
                print(f"❌ Ошибка при добавлении конфигов: {e}")
                self._connection.rollback()
                return -1

    def update_statistics (self,
                        university_name: str,
                        number_of_students: int = None,
                        number_of_faculties: int = None) -> bool:
        """
        Добавление  статистики университета

        Args:
            university_name: Название университета
            number_of_students: Количество студентов
            number_of_faculties: Количество факультетов

        Returns:
            bool: True если успешно
        """
        try:
            updates = []
            params = []

            if number_of_students is not None:
                updates.append("number_of_students = ?")
                params.append(number_of_students)

            if number_of_faculties is not None:
                updates.append("number_of_faculties = ?")
                params.append(number_of_faculties)

            if not updates:
                return False

            updates.append("last_updated = CURRENT_TIMESTAMP")
            params.append(university_name)

            query=f'''
            UPDATE university_statistics
            SET {','.join(updates)}
            WHERE university_name = ?
            '''

            self.cursor.execute(query, params)
            self._connection.commit()

            updated = self.cursor.rowcount > 0
            if updated:
               print(f"✅ Статистика обновлена для: {university_name}")

            return updated

        except Exception as e:
            print(f"❌ Ошибка обновления статистики: {e}")
            self._connection.rollback()
            return False




























