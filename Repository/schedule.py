# repositories/schedule.py
from Repository.base import BaseRepository
from typing import List, Dict, Optional


class ScheduleRepository(BaseRepository):
    def get_doctor_schedule(
        self,
        doctor_id: Optional[str] = None
    ) -> list[dict]:
        """
        Отримати розклад лікарів (опційно тільки для одного лікаря)
        через view v_doctor_schedule
        """
        with self.cursor as cur:
            if doctor_id:
                cur.execute(
                    """
                    SELECT *
                    FROM "v_doctor_schedule"
                    WHERE doctor_id = %s
                    ORDER BY starts_at
                    """,
                    [doctor_id]
                )
            else:
                cur.execute(
                    """
                    SELECT *
                    FROM "v_doctor_schedule"
                    ORDER BY starts_at
                    """
                )
            return cur.fetchall()
