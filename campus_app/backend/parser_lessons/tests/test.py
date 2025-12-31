import requests
from bs4 import BeautifulSoup
import time
from selenium import webdriver


class parser_lessons:
    def __init__(self,
                 university_name: str,
                 group: str,
                 date: str = None):
        self.university_name = university_name
        self.group = group
        self.date = date

    def get_date(self):
        if self.date == None:
            current_time = time.time()
            time_struct = time.localtime(current_time)
            date_format = f"{time_struct.tm_year}.{time_struct.tm_mon}.{time_struct.tm_day}" #ГГГГ.ММ.ДД
            return date_format
        else:
            return self.data
    
    def parser(self):
        driver = webdriver.Chrome()
        schedule_url = f"https://mpei.ru/Education/timetable/Pages/table.aspx?groupoid=19657&start={self.get_date}"
        response = requests.get(schedule_url)

        html_content = response.text
        soup = BeautifulSoup(html_content, "html.parser")


def prosto_test():
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    import time

    driver = webdriver.Chrome()
    try:
        try:
            driver.get("https://mpei.ru/Education/timetable/Pages/default.aspx")
            element_grouprow = driver.find_element(By.XPATH, '//*[@id="ctl00_ctl33_g_f0649160_e72e_4671_a36b_743021868df5"]/div/div/div/input[1]')
            element_submit_button = driver.find_element(By.XPATH, '//*[@id="ctl00_ctl33_g_f0649160_e72e_4671_a36b_743021868df5"]/div/div[1]/div/input[2]')
                                                                  
            print("Элементы нашлись, всё работает хорошо")

            try:
                element_grouprow.send_keys('А-03-23')
                time.sleep(1)
                element_submit_button.click()
                print("Всё отработало хорошо")
            
            except Exception as e:
                print(f"Ошибка: \n{e}")
        except Exception as e:
            print(f"Ошибка: {e}")
        
        driver.quit()

    except Exception as e:
        print(f"Ошибка во всей функции: {e}")
    

prosto_test()






    
    
        






