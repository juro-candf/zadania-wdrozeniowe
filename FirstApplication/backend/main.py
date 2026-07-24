import hashlib
import hmac
import os
import secrets
import sqlite3
from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path
from fastapi import FastAPI, HTTPException
from models import PersonIn, PersonOut, DeleteRequest

DATABASE_PATH = Path(os.environ.get("DATABASE_PATH", "data/app.db"))

def get_connection() -> sqlite3.Connection:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    return connection

def create_database() -> None:
    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)

    with get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS people (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                surname TEXT NOT NULL,
                date_of_birth TEXT NOT NULL,
                swag_level INTEGER NOT NULL,
                password_salt BLOB NOT NULL,
                password_hash TEXT NOT NULL
            )
            """
        )

@asynccontextmanager
async def lifespan(_: FastAPI):
    create_database()
    yield


app = FastAPI(lifespan=lifespan)

#_db: dict[int, PersonOut] = {}
#_credentials: dict[int, tuple[bytes, str]] = {}
#_next_id = 1

def hash_password(password: str, salt: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000).hex()

def calculate_age(date_of_birth: date) -> int:
    today = date.today()
    return today.year - date_of_birth.year - (
        (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
    )

def person_from_row(row: sqlite3.Row) -> PersonOut:
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

    with get_connection() as connection:
        cursor = connection.execute(
            """
            INSERT INTO people (
                name, surname, date_of_birth, swag_level, password_salt, password_hash
            )
            VALUES (?, ?, ?, ?, ?, ?)
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
        person_id = cursor.lastrowid

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
    with get_connection() as connection:
        row = connection.execute(
            """
            SELECT id, name, surname, date_of_birth, swag_level
            FROM people
            WHERE id = ?
            """,
            (person_id,),
        ).fetchone()

    if row is None:
        raise HTTPException(status_code=404, detail="Person not found")

    return person_from_row(row)

@app.get("/people", response_model=list[PersonOut])
async def list_people():
    with get_connection() as connection:
        rows = connection.execute(
            """
            SELECT id, name, surname, date_of_birth, swag_level
            FROM people
            ORDER BY id
            """
        ).fetchall()

    return [person_from_row(row) for row in rows]

@app.delete("/people/{person_id}")
async def delete_person(person_id: int, payload: DeleteRequest):
    with get_connection() as connection:
        row = connection.execute(
            "SELECT password_salt, password_hash FROM people WHERE id = ?",
            (person_id,),
        ).fetchone()

        if row is None:
            raise HTTPException(status_code=404, detail="Person not found")

        if not hmac.compare_digest(
            hash_password(payload.password, row["password_salt"]),
            row["password_hash"],
        ):
            raise HTTPException(status_code=403, detail="Incorrect password")

        connection.execute("DELETE FROM people WHERE id = ?", (person_id,))

    return {"detail": "Person removed"}