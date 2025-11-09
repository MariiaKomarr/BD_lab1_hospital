# repositories/base.py
class BaseRepository:
    def __init__(self, connection):
        self.conn = connection

    @property
    def cursor(self):
        return self.conn.cursor()

