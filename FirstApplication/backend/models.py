from pydantic import BaseModel, field_validator
from datetime import date

class PersonBase(BaseModel):
    name: str
    surname: str
    date_of_birth: date
    swag_level: int

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
    
    @field_validator("swag_level")
    @classmethod
    def non_negative_swag_level(cls, v: int) -> int:
        if v < 500:
            raise ValueError("You must have a swag level of at least 500 to be considered cool.")
        if v > 100000:
            raise ValueError("Swag levels do not exceed 100000, you liar!")
        return v

class PersonIn(PersonBase):
    password: str

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 4:
            raise ValueError("Password must be at least 4 characters long.")
        return v

class PersonOut(PersonBase):
    id: int
    age: int

class DeleteRequest(BaseModel):
    password: str