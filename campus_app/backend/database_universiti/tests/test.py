from database_universiti.database_universities import UniversityDatabase

if __name__ == '__main__':
    db = UniversityDatabase("test_universities.db")

    print("=" * 60)
    print("ТЕСТИРОВАНИЕ БАЗЫ ДАННЫХ УНИВЕРСИТЕТОВ")
    print("=" * 60)

    # 1. Добавляем университет
    print("\n1. Добавляем университет МГУ:")
    msu_id = db.add_university(
        name="МГУ",
        city="Москва",
        schedule_url="https://www.msu.ru/schedule",
        official_website="https://www.msu.ru",
        full_name_university="Московский государственный университет",
        schedule_type="html"
    )

    # 2. Добавляем факультеты
    print("\n2. Добавляем факультеты МГУ:")
    db.add_faculty(
        university_name="МГУ",
        name_faculty="Мехмат",
        full_name_faculty="Механико-математический факультет",
        faculty_url="https://mech.math.msu.su"
    )


    # 3. Добавляем конфиг парсера
    print("\n3. Добавляем конфиг парсера для МГУ:")
    db.add_parser_config(
        university_name="МГУ",
        config={
            "parser_type": "html",
            "selectors": {
                "table": ".schedule-table",
                "time": ".time-cell",
                "subject": ".subject-name"
            }
        }
    )

    # 4. Обновляем статистику
    print("\n4. Обновляем статистику МГУ:")
    db.update_statistics(
        university_name="МГУ",
        number_of_students=35000,
        number_of_faculties=45
    )


    # 7. Пробуем добавить дубликат (должна быть ошибка)
    print("\n7. Пробуем добавить дубликат МГУ:")
    db.add_university(
        name="МГУ",
        city="Москва",
        schedule_url="https://example.com"
    )

    # 8. Пробуем добавить факультет к несуществующему вузу
    print("\n8. Пробуем добавить факультет к несуществующему вузу:")
    db.add_faculty(
        university_name="Несуществующий",
        name_faculty="Факультет"
    )

    db.close()