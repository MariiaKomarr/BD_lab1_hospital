# Hospital Management Database (PostgreSQL + Python)

Цей проєкт — навчальна система керування лікарнею, що демонструє роботу з **PostgreSQL** та **Python** із використанням архітектурних патернів **Repository** і **Unit of Work**.  
Система охоплює повний цикл роботи з даними: пацієнти, лікарі, госпіталізації, рахунки, процедури, медикаменти, лабораторні тести, оплати та автоматизацію аудиту через тригери.

---

## Структура репозиторію

```
.
├─ Repository/          # Класи-репозиторії для доступу до окремих сутностей
│  ├─ base.py           # Базовий клас із логікою роботи з курсором
│  ├─ patients.py       # Репозиторій для таблиці patients (CRUD + soft delete)
│  ├─ doctors.py        # Репозиторій для таблиці doctors (створення лікаря)
│  ├─ admissions.py     # Репозиторій для госпіталізацій (створення, виписка)
│  ├─ billing.py        # Репозиторій для білінгу (баланс, сума рахунку)
│  └─ schedule.py       # Репозиторій для в’ю v_doctor_schedule
│
├─ __pycache__/         # Технічна папка для кешу Python
│
├─ backup.sql           # Основний SQL dump: таблиці, ключі, функції, тригери, дані
│
├─ db.py                # Параметри підключення до бази PostgreSQL
│
├─ main.py              # Головний консольний застосунок із меню користувача
│
├─ scripts.zip          # Архів зі скриптами створення процедур, функцій, тригерів, в’ю
│
└─ unit_of_work.py      # Патерн Unit of Work: транзакції, commit/rollback, репозиторії
```

---

## Призначення проєкту

Проєкт створено для демонстрації:

- побудови структурованої бази даних лікарні;
- роботи з **PL/pgSQL**: функції, процедури, тригери, в’ю;
- реалізації **Repository + Unit of Work** у Python;
- транзакційного контролю операцій;
- аудиту через тригери (`created_at`, `updated_at`);
- зручного керування сутностями через консоль.

---

## Технології

- **PostgreSQL 14+**
- **Python 3.10+**
- **psycopg2-binary** — драйвер для підключення до PostgreSQL
- **PL/pgSQL** — процедурна мова PostgreSQL для логіки на стороні БД

---

## Файли проєкту

### `backup.sql`

Повний дамп бази даних, який включає:

- **DDL** — створення таблиць, первинних і зовнішніх ключів, унікальних індексів;
- **DML** — тестові записи (приблизно 10 у кожній таблиці);
- **Тригери**: автоматичне оновлення полів `created_at`, `updated_at`;
- **Процедури**:
  - `discharge_patient()` — виписка пацієнта з оновленням ліжка;
  - `soft_delete_patient()` — м’яке видалення пацієнта та відміна візитів;
- **Функції**:
  - `calc_invoice_total()` — підрахунок суми рахунку;
  - `get_patient_balance()` — підрахунок залишку коштів;
  - `set_audit_fields()` — функція тригера для оновлення timestamp;
- **В’ю**:
  - `v_active_patients` — активні пацієнти;
  - `v_current_inpatients` — поточні госпіталізації;
  - `v_doctor_schedule` — розклад лікарів.

---

## Архів `scripts.zip`

Містить окремі SQL-файли:

```
created_tables.session     # Створення всіх таблиць і зв’язків між ними
created_function.sql        # Створення функцій (наприклад set_audit_fields, calc_invoice_total тощо)
created_procedure.sql       # Збережені процедури (discharge_patient, soft_delete_patient)
created_trigger.sql         # Тригери для автоматичного оновлення created_at / updated_at
view_created.sql            # В’ю (v_active_patients, v_current_inpatients, v_doctor_schedule)
```

> Ці файли дозволяють швидко відтворити окремі частини без запуску всього дампу.

---

## Налаштування підключення (`db.py`)

Вкажи свої дані для підключення до PostgreSQL:

```python
DB_HOST = "localhost"
DB_PORT = 5432
DB_NAME = "hospital_db"
DB_USER = "postgres"
DB_PASSWORD = "your_password"
```

---

## Розгортання бази даних

1. Створи базу:

   ```sql
   CREATE DATABASE hospital_db;
   ```

2. Імпортуй дамп:

   ```bash
   psql -U postgres -d hospital_db -f backup.sql
   ```

3. За потреби виконай скрипти з `scripts.zip` у порядку:

   - `tables.sql`
   - `functions.sql`
   - `procedures.sql`
   - `triggers.sql`
   - `views.sql`

---

## Запуск Python-застосунку

```bash
python main.py
```

У консолі з’явиться меню:

| №  | Дія                             | Опис                                 |
| -- | ------------------------------- | ------------------------------------ |
| 1  | Додати пацієнта                 | Створення запису у `patients`        |
| 2  | Додати лікаря                   | Створення запису у `doctors`         |
| 3  | Додати госпіталізацію           | Додавання у `admissions`             |
| 4  | Показати `v_active_patients`    | Список активних пацієнтів            |
| 5  | Показати `v_current_inpatients` | Поточні госпіталізовані              |
| 6  | Показати `v_doctor_schedule`    | Розклад лікарів                      |
| 7  | Виписати пацієнта               | Виклик процедури `discharge_patient` |
| 8  | Показати баланс пацієнта        | Виклик `get_patient_balance`         |
| 9  | Показати суму рахунку           | Виклик `calc_invoice_total`          |
| 10 | Показати будь-яку таблицю       | `SELECT * FROM "<table>"`            |
| 0  | Вихід                           | Завершення програми                  |

---

## Архітектура коду

### Repository

Кожен клас відповідає за одну таблицю або в’ю:

- `PatientRepository` — керування пацієнтами;
- `DoctorRepository` — створення лікарів;
- `AdmissionRepository` — госпіталізації, виписки;
- `BillingRepository` — робота з рахунками, балансом;
- `ScheduleRepository` — розклад лікарів (через view);
- `BaseRepository` — базові методи для роботи з курсором.

Приклад використання:

```python
with UnitOfWork() as uow:
    new_patient_id = uow.patients.create(
        mrn="MR010",
        full_name="John Doe",
        birth_date="1990-05-10"
    )
```

---

### Unit of Work

Інкапсулює одну транзакцію для кількох репозиторіїв.  
Автоматично виконує **commit** або **rollback** при помилці.

```python
from unit_of_work import UnitOfWork

with UnitOfWork() as uow:
    uow.patients.create("MR002", "Jane Smith")
    uow.doctors.create("L-100", "Therapist")
# commit → дані збережені
```

---

## SQL-приклади для перевірки

```sql
-- Активні пацієнти
SELECT * FROM "v_active_patients";

-- Госпіталізації
SELECT * FROM "v_current_inpatients";

-- Розклад лікарів
SELECT * FROM "v_doctor_schedule";

-- Сума рахунку
SELECT calc_invoice_total('inv1');

-- Баланс пацієнта
SELECT get_patient_balance('pat1');
```

---

## Логіка тригерів

### `set_audit_fields()`

Функція автоматично оновлює поля аудиту:

- `created_at` — при вставці (`INSERT`);
- `updated_at` — при оновленні (`UPDATE`).

```sql
CREATE TRIGGER trg_patients_audit
BEFORE INSERT OR UPDATE ON "patients"
FOR EACH ROW
EXECUTE FUNCTION set_audit_fields();
```

> Аналогічні тригери створено для таблиць `doctors`, `admissions` та інших.

---

## Приклад транзакції

1. Додай пацієнта.  
2. Додай лікаря.  
3. Госпіталізуй пацієнта.  
4. Виклич `discharge_patient()` — пацієнта буде виписано, а ліжко звільнено.  
5. Якщо всі кроки пройшли успішно — транзакція зберігається (`commit`).

---

## Автор

**Mariia Komar**  
Студентка 3 курсу, група ТК-31

