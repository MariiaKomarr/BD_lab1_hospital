# Repository/patients.py
import uuid
from Repository.base import BaseRepository


class PatientRepository(BaseRepository):
    def get_all_active(self):
        with self.cursor as cur:
            cur.execute('SELECT * FROM "v_active_patients" ORDER BY full_name')
            return cur.fetchall()

    def get_by_id(self, patient_id: str):
        with self.cursor as cur:
            cur.execute(
                'SELECT * FROM "v_active_patients" WHERE id = %s',
                [patient_id],
            )
            return cur.fetchone()

    def soft_delete(self, patient_id: str, user_id: str):
        with self.cursor as cur:
            cur.execute(
                "CALL soft_delete_patient(%s, %s)",
                [patient_id, user_id],
            )

    # 🔹 НОВЕ — створення пацієнта
    def create(
        self,
        mrn: str,
        full_name: str,
        birth_date: str | None = None,
        phone: str | None = None,
        address: str | None = None,
        emergency_contact: str | None = None,
        created_by: str | None = None,
    ) -> str:
        patient_id = str(uuid.uuid4())
        with self.cursor as cur:
            cur.execute(
                """
                INSERT INTO "patients" (
                    id, mrn, full_name, birth_date,
                    phone, address, emergency_contact, created_by
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                [
                    patient_id,
                    mrn,
                    full_name,
                    birth_date,
                    phone,
                    address,
                    emergency_contact,
                    created_by,
                ],
            )
        # тригер виставить created_at
        return patient_id
