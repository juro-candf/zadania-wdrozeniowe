import os
import tempfile
from pathlib import Path

import pytest

_tmp_dir = tempfile.TemporaryDirectory()
os.environ["DATABASE_PATH"] = str(Path(_tmp_dir.name) / "test.db")

from fastapi.testclient import TestClient
from main import app


@pytest.fixture()
def client():
    with TestClient(app) as c:
        yield c


def make_person_payload(**overrides):
    payload = {
        "name": "Ophelia",
        "surname": "Pane",
        "date_of_birth": "2004-02-22",
        "swag_level": 900,
        "password": "0987",
    }
    payload.update(overrides)
    return payload


def test_create_person(client):
    response = client.post("/people", json=make_person_payload())
    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Ophelia"
    assert "id" in body
    assert "password" not in body


def test_get_person(client):
    created = client.post("/people", json=make_person_payload(name="Chip")).json()

    response = client.get(f"/people/{created['id']}")
    assert response.status_code == 200
    assert response.json()["name"] == "Chip"


def test_get_person_not_found(client):
    response = client.get("/people/999999")
    assert response.status_code == 404


def test_list_people(client):
    client.post("/people", json=make_person_payload(name="Mimi"))
    client.post("/people", json=make_person_payload(name="Nyami"))

    response = client.get("/people")
    assert response.status_code == 200
    names = [p["name"] for p in response.json()]
    assert "Mimi" in names
    assert "Nyami" in names


def test_delete_person_wrong_password(client):
    created = client.post("/people", json=make_person_payload()).json()

    response = client.request(
        "DELETE", f"/people/{created['id']}", json={"password": "wrong"}
    )
    assert response.status_code == 403


def test_delete_person(client):
    created = client.post("/people", json=make_person_payload()).json()

    response = client.request(
        "DELETE", f"/people/{created['id']}", json={"password": "0987"}
    )
    assert response.status_code == 200

    assert client.get(f"/people/{created['id']}").status_code == 404

def test_delete_person_not_found(client):
    response = client.request("DELETE", "/people/999999", json={"password": "anything"})
    assert response.status_code == 404

def test_get_person_invalid_id_type(client):
    response = client.get("/people/not-an-int")
    assert response.status_code == 422

def test_create_person_invalid_date_format(client):
    response = client.post("/people", json=make_person_payload(date_of_birth="not-a-date"))
    assert response.status_code == 422

def test_create_person_future_date_of_birth(client):
    response = client.post("/people", json=make_person_payload(date_of_birth="2999-01-01"))
    assert response.status_code == 422

def test_create_person_name_with_digits(client):
    response = client.post("/people", json=make_person_payload(name="Chip3"))
    assert response.status_code == 422

def test_create_person_surname_with_digits(client):
    response = client.post("/people", json=make_person_payload(surname="Pane99"))
    assert response.status_code == 422

def test_create_person_missing_field(client):
    payload = make_person_payload()
    del payload["password"]
    response = client.post("/people", json=payload)
    assert response.status_code == 422

def test_create_person_password_too_short(client):
    response = client.post("/people", json=make_person_payload(password="abc"))
    assert response.status_code == 422

@pytest.mark.parametrize("swag_level", [10, 200000])
def test_create_person_invalid_swag_level(client, swag_level):
    response = client.post("/people", json=make_person_payload(swag_level=swag_level))
    assert response.status_code == 422

def test_create_person_swag_level_too_low_message(client):
    response = client.post("/people", json=make_person_payload(swag_level=10))
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert any("at least 500" in error["msg"] for error in detail)

def test_create_person_swag_level_too_high_message(client):
    response = client.post("/people", json=make_person_payload(swag_level=200000))
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert any("do not exceed 100000" in error["msg"] for error in detail)

@pytest.mark.parametrize("swag_level", [500, 100000])
def test_create_person_swag_level_boundaries_valid(client, swag_level):
    response = client.post("/people", json=make_person_payload(swag_level=swag_level))
    assert response.status_code == 200

@pytest.mark.parametrize("swag_level", [499, 100001])
def test_create_person_swag_level_boundaries_invalid(client, swag_level):
    response = client.post("/people", json=make_person_payload(swag_level=swag_level))
    assert response.status_code == 422

def test_create_person_empty_name(client):
    response = client.post("/people", json=make_person_payload(name="   "))
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert any("cannot be empty" in error["msg"] for error in detail)

def test_create_person_empty_surname(client):
    response = client.post("/people", json=make_person_payload(surname="   "))
    assert response.status_code == 422

def test_age_calculated_correctly(client):
    from datetime import date
    dob = date(2000, 1, 1)
    created = client.post(
        "/people", json=make_person_payload(date_of_birth=dob.isoformat())
    ).json()

    expected_age = date.today().year - dob.year - (
        (date.today().month, date.today().day) < (dob.month, dob.day)
    )
    assert created["age"] == expected_age

def test_create_person_date_of_birth_today(client):
    from datetime import date
    response = client.post(
        "/people", json=make_person_payload(date_of_birth=date.today().isoformat())
    )
    assert response.status_code == 200

def test_deleted_person_removed_from_list_others_remain(client):
    keep = client.post("/people", json=make_person_payload(name="Keeper")).json()
    remove = client.post("/people", json=make_person_payload(name="Removed")).json()

    client.request("DELETE", f"/people/{remove['id']}", json={"password": "0987"})

    names = [p["name"] for p in client.get("/people").json()]
    assert "Removed" not in names
    assert "Keeper" in names


def test_ids_increase_across_creates(client):
    first = client.post("/people", json=make_person_payload(name="First")).json()
    second = client.post("/people", json=make_person_payload(name="Second")).json()
    assert second["id"] > first["id"]

def test_create_person_swag_level_wrong_type(client):
    response = client.post("/people", json=make_person_payload(swag_level="not-a-number"))
    assert response.status_code == 422

def test_list_people_no_password_leak(client):
    client.post("/people", json=make_person_payload(name="Secretive"))
    response = client.get("/people")
    assert all("password" not in person for person in response.json())