import hashlib
import hmac
import secrets
from fastapi import FastAPI, HTTPException
from datetime import date
from models import PersonIn, PersonOut, DeleteRequest

app = FastAPI()

_db: dict[int, PersonOut] = {}
_credentials: dict[int, tuple[bytes, str]] = {}
_next_id = 1

def hash_password(password: str, salt: bytes) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 100_000).hex()

#@app.get("/")
#async def root():
#    return {"message": "Hello World"}

@app.post("/people", response_model=PersonOut)
async def create_person(person: PersonIn):
    global _next_id
    today = date.today()
    age = today.year - person.date_of_birth.year - ((today.month, today.day) < (person.date_of_birth.month, person.date_of_birth.day))
    data = person.model_dump(exclude={"password"})
    record = PersonOut(**data, id=_next_id, age=age)
    salt = secrets.token_bytes(16)
    _credentials[_next_id] = (salt, hash_password(person.password, salt))
    _db[_next_id] = record
    _next_id += 1
    return record

@app.get("/people/{person_id}", response_model=PersonOut)
async def get_person(person_id: int):
    if person_id not in _db:
        raise HTTPException(status_code=404, detail="Person not found")
    return _db[person_id]

@app.get("/people", response_model=list[PersonOut])
async def list_people():
    return list(_db.values())

@app.delete("/people/{person_id}")
async def delete_person(person_id: int, payload: DeleteRequest):
    if person_id not in _db:
        raise HTTPException(status_code=404, detail="Person not found")
    salt, stored_hash = _credentials[person_id]
    if not hmac.compare_digest(hash_password(payload.password, salt), stored_hash):
        raise HTTPException(status_code=403, detail="Incorrect password")
    del _db[person_id]
    del _credentials[person_id]
    return {"Person removed"}