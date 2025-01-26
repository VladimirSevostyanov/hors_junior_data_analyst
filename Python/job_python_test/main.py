import pymysql
from rapidfuzz import fuzz, process

# Подключение к базе данных. Вставьте ваш хост, пользователь, пароль и базу данных
connection = pymysql.connect(
    host='',
    user='',
    password='',
    database=''
)

def normalize(text):
    # Нормализация текста
    if text:
        return ' '.join(text.lower().replace('.', '').replace(',', '').split())
    return None

def deduplicate_outlets():
    try:
        with connection.cursor() as cursor:
            # Получение данных из таблицы outlets
            cursor.execute("SELECT id, Торг_точка_грязная, Торг_точка_грязная_адрес FROM outlets;")
            outlets = cursor.fetchall()

            clean_outlets = {}
            clean_id = 1

            for outlet in outlets:
                outlet_id, dirty_name, dirty_address = outlet
                # Обрезка текста, так как больше не помещается
                combined_text = (normalize(dirty_name) + ' ' + normalize(dirty_address))[:145]

                # Проверяем схожесть с существующими чистыми точками
                match = process.extractOne(combined_text, clean_outlets.keys(), scorer=fuzz.token_sort_ratio)
                if match and match[1] > 90:  # Порог схожести
                    clean_outlet_id = clean_outlets[match[0]]
                else:
                    # Добавляем новую точку в clean_outlets
                    clean_outlets[combined_text] = clean_id
                    cursor.execute(
                        "INSERT INTO outlets_clean (id, Торг_точка_чистый_адрес) VALUES (%s, %s)",
                        (clean_id, combined_text)
                    )
                    clean_outlet_id = clean_id
                    clean_id += 1

                # Обновляем outlet_clean_id в таблице outlets
                cursor.execute(
                    "UPDATE outlets SET outlet_clean_id = %s WHERE id = %s", (clean_outlet_id, outlet_id)
                )
        connection.commit()
    except Exception as e:
        print("Ошибка:", e)
        connection.rollback()
    finally:
        connection.close()


if __name__ == "__main__":
    deduplicate_outlets()
