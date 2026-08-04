import hashlib
import hmac
import os
import secrets
import psycopg2
import psycopg2.extras
from contextlib import asynccontextmanager
from datetime import date
from fastapi import FastAPI, HTTPException
from models import PersonIn, PersonOut, DeleteRequest

def get_db_config():
    return {
        "host": os.environ["POSTGRES_HOST"],
        "port": os.environ.get("POSTGRES_PORT", "5432"),
        "dbname": os.environ["POSTGRES_DB"],
        "user": os.environ["POSTGRES_USER"],
        "password": os.environ["POSTGRES_PASSWORD"],
    }

def get_connection():
    connection = psycopg2.connect(**get_db_config(), cursor_factory=psycopg2.extras.RealDictCursor)
    return connection


def create_database() -> None:
    with get_connection() as connection, connection.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS people (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                surname TEXT NOT NULL,
                date_of_birth TEXT NOT NULL,
                swag_level INTEGER NOT NULL,
                password_salt BYTEA NOT NULL,
                password_hash TEXT NOT NULL
            )
            """
        )
    connection.close()

@asynccontextmanager
async def lifespan(_: FastAPI):
    create_database()
    yield


app = FastAPI(lifespan=lifespan)

#_db: dict[int, PersonOut] = {}
#_credentials: dict[int, tuple[bytes, str]] = {}
#_next_id = 1

@app.get("/health")
async def health():
    return {"status": "ok"}

def hash_password(password: str, salt: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000).hex()

def calculate_age(date_of_birth: date) -> int:
    today = date.today()
    return today.year - date_of_birth.year - (
        (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
    )

def person_from_row(row: psycopg2.extras.RealDictRow) -> PersonOut:
    date_of_birth = date.fromisoformat(row["date_of_birth"])

    return PersonOut(
        id=row["id"],
        name=row["name"],
        surname=row["surname"],
        date_of_birth=date_of_birth,
        swag_level=row["swag_level"],
        age=calculate_age(date_of_birth),
    )

#@app.get("/")
#async def root():
#    return {"message": "Hello World"}

@app.post("/people", response_model=PersonOut)
async def create_person(person: PersonIn):
    salt = secrets.token_bytes(16)
    password_hash = hash_password(person.password, salt)

    connection = get_connection()
    try:
        with connection, connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO people (
                    name, surname, date_of_birth, swag_level, password_salt, password_hash
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id
                """,
                (
                    person.name,
                    person.surname,
                    person.date_of_birth.isoformat(),
                    person.swag_level,
                    salt,
                    password_hash,
                ),
            )
            person_id = cursor.fetchone()["id"]
    finally:
        connection.close()

    return PersonOut(
        id=person_id,
        name=person.name,
        surname=person.surname,
        date_of_birth=person.date_of_birth,
        swag_level=person.swag_level,
        age=calculate_age(person.date_of_birth),
    )

@app.get("/people/{person_id}", response_model=PersonOut)
async def get_person(person_id: int):
    connection = get_connection()
    try:
        with connection, connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, surname, date_of_birth, swag_level
                FROM people
                WHERE id = %s
                """,
                (person_id,),
            )
            row = cursor.fetchone()
    finally:
        connection.close()

    if row is None:
        raise HTTPException(status_code=404, detail="Person not found")

    return person_from_row(row)

@app.get("/people", response_model=list[PersonOut])
async def list_people():
    connection = get_connection()
    try:
        with connection, connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, name, surname, date_of_birth, swag_level
                FROM people
                ORDER BY id
                """
            )
            rows = cursor.fetchall()
    finally:
        connection.close()

    return [person_from_row(row) for row in rows]

@app.delete("/people/{person_id}")
async def delete_person(person_id: int, payload: DeleteRequest):
    connection = get_connection()
    try:
        with connection, connection.cursor() as cursor:
            cursor.execute(
                "SELECT password_salt, password_hash FROM people WHERE id = %s",
                (person_id,),
            )
            row = cursor.fetchone()

            if row is None:
                raise HTTPException(status_code=404, detail="Person not found")

            if not hmac.compare_digest(
                hash_password(payload.password, bytes(row["password_salt"])),
                row["password_hash"],
            ):
                raise HTTPException(status_code=403, detail="Incorrect password")

            cursor.execute("DELETE FROM people WHERE id = %s", (person_id,))
    finally:
        connection.close()

    return {"detail": "Person removed"}