from fastapi import FastAPI, HTTPException
from datetime import date
from models import PersonIn, PersonOut

app = FastAPI()

_db: dict[int, PersonOut] = {}
_next_id = 1

#@app.get("/")
#async def root():
#    return {"message": "Hello World"}

@app.post("/people", response_model=PersonOut)
async def create_person(person: PersonIn):
    global _next_id
    today = date.today()
    age = today.year - person.date_of_birth.year - ((today.month, today.day) < (person.date_of_birth.month, person.date_of_birth.day))
    record = PersonOut(**person.model_dump(), id=_next_id, age=age)
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