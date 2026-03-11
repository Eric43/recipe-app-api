"""
Django command to wait for the database to be available
"""
import time

from psycopg import OperationalError as PsycopgOpError

from django.db.utils import OperationalError
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    """Django command to wait for db."""

    def handle(self, *args, **options):
        """Entry point for the command."""

        self.stdout.write('Waiting for DB...')
        db_up = False
        while db_up is False:
            try:
                self.check(databases=['default'])
                db_up = True
            except (PsycopgOpError, OperationalError):
                self.stdout.write('Database unavailabe, waiting one second.')
                time.sleep(1)

        self.stdout.write(self.style.SUCCESS('Database is available.'))
