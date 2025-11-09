from unit_of_work import UnitOfWork


def prompt_patient():
    mrn = input("MRN (обов'язково): ").strip()
    full_name = input("ПІБ (обов'язково): ").strip()
    birth_date = input("Дата народження (YYYY-MM-DD, можна пусто): ").strip()
    phone = input("Телефон (можна пусто): ").strip()
    address = input("Адреса (можна пусто): ").strip()
    emergency_contact = input("Екстрений контакт (можна пусто): ").strip()
    created_by = input("created_by (UUID користувача, можна пусто): ").strip()

    if not mrn or not full_name:
        print("MRN і ПІБ обов'язкові")
        return

    with UnitOfWork() as uow:
        pid = uow.patients.create(
            mrn=mrn,
            full_name=full_name,
            birth_date=birth_date or None,
            phone=phone or None,
            address=address or None,
            emergency_contact=emergency_contact or None,
            created_by=created_by or None,
        )
        print(f"Пацієнта створено, id = {pid}")


def prompt_doctor():
    license_no = input("Номер ліцензії (обов'язково): ").strip()
    speciality = input("Спеціальність (можна пусто): ").strip()
    user_id = input("user_id (UUID, можна пусто): ").strip()
    department_id = input("department_id (UUID, можна пусто): ").strip()
    created_by = input("created_by (UUID користувача, можна пусто): ").strip()

    if not license_no:
        print("Номер ліцензії обов'язковий")
        return

    with UnitOfWork() as uow:
        did = uow.doctors.create(
            license_no=license_no,
            speciality=speciality or None,
            user_id=user_id or None,
            department_id=department_id or None,
            created_by=created_by or None,
        )
        print(f"Лікаря створено, id = {did}")


def prompt_admission():
    patient_id = input("patient_id (UUID, обов'язково): ").strip()
    doctor_id = input("doctor_id (UUID, обов'язково): ").strip()
    bed_id = input("bed_id (UUID, можна пусто): ").strip()
    admitted_at = input("admitted_at (YYYY-MM-DD HH:MM:SS, пусто = now()): ").strip()
    status = input("status (пусто = 'admitted'): ").strip()
    created_by = input("created_by (UUID користувача, можна пусто): ").strip()

    if not patient_id or not doctor_id:
        print("patient_id і doctor_id обов'язкові")
        return

    with UnitOfWork() as uow:
        aid = uow.admissions.create(
            patient_id=patient_id,
            doctor_id=doctor_id,
            bed_id=bed_id or None,
            admitted_at=admitted_at or None,
            status=status or None,
            created_by=created_by or None,
        )
        print(f"Госпіталізацію створено, id = {aid}")


def show_active_patients():
    with UnitOfWork() as uow:
        rows = uow.patients.get_all_active()
        print("\n=== v_active_patients ===")
        if not rows:
            print("Немає активних пацієнтів")
            return
        for r in rows:
            print(f"- {r['id']} | {r['full_name']} | MRN: {r['mrn']}")


def show_current_inpatients():
    with UnitOfWork() as uow:
        rows = uow.admissions.get_current_inpatients()
        print("\n=== v_current_inpatients ===")
        if not rows:
            print("Немає поточних стаціонарних")
            return
        for r in rows:
            print(
                f"- admission_id={r['admission_id']} | {r['patient_name']} | "
                f"room={r['room_code']} | bed={r['bed_no']} | dept={r['department_name']}"
            )


def show_doctor_schedule():
    doctor_id = input("doctor_id (UUID, пусто = всі лікарі): ").strip() or None
    with UnitOfWork() as uow:
        rows = uow.schedule.get_doctor_schedule(doctor_id)
        print("\n=== v_doctor_schedule ===")
        if not rows:
            print("Немає записів у розкладі")
            return
        for r in rows:
            print(
                f"- {r['starts_at']}–{r['ends_at']} | {r['doctor_name']} → "
                f"{r['patient_name']} ({r['department_name']})"
            )


def prompt_discharge():
    admission_id = input("admission_id (UUID, обов'язково): ").strip()
    user_id = input("user_id (UUID, хто виписує, обов'язково): ").strip()
    discharged_at = input("discharged_at (YYYY-MM-DD HH:MM:SS, пусто = now()): ").strip()

    if not admission_id or not user_id:
        print("admission_id і user_id обов'язкові")
        return

    with UnitOfWork() as uow:
        uow.admissions.discharge(
            admission_id=admission_id,
            user_id=user_id,
            discharged_at=discharged_at or None,
        )
        print(f"Госпіталізацію {admission_id} виписано (процедура discharge_patient)")


def prompt_patient_balance():
    patient_id = input("patient_id (UUID, обов'язково): ").strip()
    if not patient_id:
        print("patient_id обов'язковий")
        return

    with UnitOfWork() as uow:
        balance = uow.billing.get_patient_balance(patient_id)
        print(f"Баланс пацієнта {patient_id}: {balance:.2f}")


def prompt_invoice_total():
    invoice_id = input("invoice_id (UUID, обов'язково): ").strip()
    if not invoice_id:
        print("invoice_id обов'язковий")
        return

    with UnitOfWork() as uow:
        total = uow.billing.calc_invoice_total(invoice_id)
        print(f"Сума рахунку {invoice_id}: {total:.2f}")

import psycopg2.extras

def show_table():
    table_name = input("Введіть назву таблиці: ").strip()
    if not table_name:
        print("Назва таблиці обов'язкова")
        return

    with UnitOfWork() as uow:
        # Використовуємо RealDictCursor — щоб бачити реальні значення
        with uow.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            try:
                cur.execute(f'SELECT * FROM "{table_name}" LIMIT 20;')
                rows = cur.fetchall()

                print(f"\n=== {table_name} ===")
                if not rows:
                    print("Таблиця порожня.")
                    return

                # Виведення назв колонок
                colnames = list(rows[0].keys())
                print(" | ".join(colnames))
                print("-" * 80)

                # Виведення рядків таблиці
                for row in rows:
                    values = [str(row[col]) if row[col] is not None else "" for col in colnames]
                    print(" | ".join(values))

            except Exception as e:
                print(f"Помилка при читанні таблиці: {e}")


def main():
    while True:
        print("\n=== Меню ===")
        print("1 - Додати пацієнта")
        print("2 - Додати лікаря")
        print("3 - Додати госпіталізацію")
        print("4 - Показати v_active_patients")
        print("5 - Показати v_current_inpatients")
        print("6 - Показати v_doctor_schedule")
        print("7 - Виписати госпіталізацію (discharge_patient)")
        print("8 - Показати баланс пацієнта (get_patient_balance)")
        print("9 - Показати суму рахунку (calc_invoice_total)")
        print("10 - Показати таблицю (введи назву)")
        print("0 - Вихід")

        choice = input(">> ").strip()

        if choice == "1":
            prompt_patient()
        elif choice == "2":
            prompt_doctor()
        elif choice == "3":
            prompt_admission()
        elif choice == "4":
            show_active_patients()
        elif choice == "5":
            show_current_inpatients()
        elif choice == "6":
            show_doctor_schedule()
        elif choice == "7":
            prompt_discharge()
        elif choice == "8":
            prompt_patient_balance()
        elif choice == "9":
            prompt_invoice_total()
        elif choice == "10":
            show_table()
        elif choice == "0":
            print("Вихід")
            break
        else:
            print("Невірний вибір, спробуй ще раз.")


if __name__ == "__main__":
    main()
