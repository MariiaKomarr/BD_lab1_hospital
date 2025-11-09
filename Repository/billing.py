# repositories/billing.py
from Repository.base import BaseRepository


# Репозиторій для білінгу (рахунки/баланс)
class BillingRepository(BaseRepository):
    def calc_invoice_total(self, invoice_id: str) -> float:
        """
        Викликає SQL-функцію:
        SELECT calc_invoice_total(p_invoice_id);
        """
        with self.cursor as cur:
            cur.execute(
                "SELECT calc_invoice_total(%s) AS total",
                [invoice_id]
            )
            row = cur.fetchone()
            return row["total"] if row else 0.0

    def get_patient_balance(self, patient_id: str) -> float:
        """
        Викликає PL/pgSQL-функцію:
        SELECT get_patient_balance(p_patient_id);
        """
        with self.cursor as cur:
            cur.execute(
                "SELECT get_patient_balance(%s) AS balance",
                [patient_id]
            )
            row = cur.fetchone()
            return row["balance"] if row else 0.0
