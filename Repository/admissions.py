# Repository/admissions.py
import uuid
from Repository.base import BaseRepository


class AdmissionRepository(BaseRepository):
    def get_current_inpatients(self):
        with self.cursor as cur:
            cur.execute('SELECT * FROM "v_current_inpatients" ORDER BY admitted_at DESC')
            return cur.fetchall()

    def discharge(self, admission_id: str, user_id: str, discharged_at: str | None = None):
        with self.cursor as cur:
            if discharged_at is None:
                cur.execute(
                    "CALL discharge_patient(%s, %s)",
                    [admission_id, user_id],
                )
            else:
                cur.execute(
                    "CALL discharge_patient(%s, %s, %s)",
                    [admission_id, user_id, discharged_at],
                )

    # 🔹 НОВЕ — створення госпіталізації
    def create(
        self,
        patient_id: str,
        doctor_id: str,
        bed_id: str | None = None,
        admitted_at: str | None = None,   # 'YYYY-MM-DD HH:MM:SS' або None
        status: str | None = None,
        created_by: str | None = None,
    ) -> str:
        admission_id = str(uuid.uuid4())
        with self.cursor as cur:
            cur.execute(
                """
                INSERT INTO "admissions" (
                    id, patient_id, doctor_id, bed_id,
                    admitted_at, status, created_by
                )
                VALUES (
                    %s, %s, %s, %s,
                    COALESCE(%s, now()),
                    COALESCE(%s, 'admitted'),
                    %s
                )
                """,
                [
                    admission_id,
                    patient_id,
                    doctor_id,
                    bed_id,
                    admitted_at,
                    status,
                    created_by,
                ],
            )
        # тригер виставить created_at
        return admission_id
