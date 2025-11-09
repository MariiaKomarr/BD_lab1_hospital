# Repository/doctors.py
import uuid
from Repository.base import BaseRepository


class DoctorRepository(BaseRepository):
    def create(
        self,
        license_no: str,
        speciality: str | None = None,
        user_id: str | None = None,
        department_id: str | None = None,
        created_by: str | None = None,
    ) -> str:
        doctor_id = str(uuid.uuid4())
        with self.cursor as cur:
            cur.execute(
                """
                INSERT INTO "doctors" (
                    id, user_id, department_id,
                    license_no, speciality, created_by
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                [
                    doctor_id,
                    user_id,
                    department_id,
                    license_no,
                    speciality,
                    created_by,
                ],
            )
        # тригер виставить created_at
        return doctor_id
