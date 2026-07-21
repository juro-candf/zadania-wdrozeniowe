import streamlit as st
import requests
from datetime import date

API_URL = "http://127.0.0.1:8000"

st.title("Register here for a free amazon giftcard!!1")

with st.form("person_form", clear_on_submit=True):
    name = st.text_input("Name")
    surname = st.text_input("Surname")
    date_of_birth = st.date_input("Date of Birth", value=date(2000, 1, 1), min_value=date(1900, 1, 1), max_value=date.today())
    submitted = st.form_submit_button("Request your giftcard now!!1")

if submitted:
    payload = {
        "name": name,
        "surname": surname,
        "date_of_birth": date_of_birth.isoformat()
    }
    try:
        response = requests.post(f"{API_URL}/people", json=payload, timeout=5)
        response.raise_for_status()
        st.success(f"Registered {name} {surname} for a free giftcard.")
    except requests.exceptions.HTTPError:
        detail = response.json().get("detail", "An error occured while registering.")
        if isinstance(detail, list):
            messages = dict.fromkeys(err["msg"].removeprefix("Value error, ") for err in detail)
            detail = "; ".join(messages)
        st.error(detail)
        #st.error(response.json().get("detail", "An error occurred while adding the person."))
    except requests.exceptions.ConnectionError:
        st.error("Could not connect to the API. Go like... check if it's running or something.")

st.subheader("Check out the people who got their free amazon giftcards!")
try:
    people = requests.get(f"{API_URL}/people", timeout=5).json()
    if people:
        st.table(people)
    else:
        st.info("Like a thousand people... totally!! And everyone got their giftcards... So don't question it man... Just trust me.")
except requests.exceptions.ConnectionError:
    st.error("Could not connect to the API. Go like... check if it's running or something.")