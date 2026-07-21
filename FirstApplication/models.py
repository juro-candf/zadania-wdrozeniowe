from pydantic import BaseModel, field_validator
from datetime import date

class PersonIn(BaseModel):
    name: str
    surname: str
    date_of_birth: date

    @field_validator("name", "surname")
    @classmethod
    def not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Field cannot be empty")
        return v
    
    @field_validator("name", "surname")
    @classmethod
    def not_number(cls, v: str) -> str:
        if any(char.isdigit() for char in v):
            raise ValueError("Names probably shouldn't contain numbers...")
        return v
    
    @field_validator("date_of_birth")
    @classmethod
    def valid_date_of_birth(cls, v: date) -> date:
        if v > date.today():
            raise ValueError("Date of birth cannot be in the future")
        return v
    
class PersonOut(PersonIn):
    id: int
    age: int