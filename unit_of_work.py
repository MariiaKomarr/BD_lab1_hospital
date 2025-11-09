# unit_of_work.py
from db import get_connection
from Repository.patients import PatientRepository
from Repository.admissions import AdmissionRepository
from Repository.billing import BillingRepository
from Repository.schedule import ScheduleRepository
from Repository.doctors import DoctorRepository


class UnitOfWork:
    def __init__(self):
        self.conn = get_connection()
        self.conn.autocommit = False

        self.patients = PatientRepository(self.conn)
        self.doctors = DoctorRepository(self.conn)
        self.admissions = AdmissionRepository(self.conn)
        self.billing = BillingRepository(self.conn)
        self.schedule = ScheduleRepository(self.conn)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None:
            self.conn.commit()
            print("Transaction committed")
        else:
            self.conn.rollback()
            print("Transaction rolled back:", exc_val)
        self.conn.close()
