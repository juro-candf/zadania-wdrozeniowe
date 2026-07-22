import streamlit as st
import requests
from datetime import date

API_URL = "http://127.0.0.1:8000"

st.title("List of cool people")

with st.form("person_form", clear_on_submit=True):
    name = st.text_input("Name")
    surname = st.text_input("Surname")
    date_of_birth = st.date_input("Date of Birth", value=date(2000, 1, 1), min_value=date(1900, 1, 1), max_value=date.today())
    swag_level = st.number_input("Level of swag", min_value=0, value=0, step=50)
    password = st.text_input("Set your epic password (you'll need it to remove yourself from the list)", type="password")
    submitted = st.form_submit_button("Join the list")

if submitted:
    payload = {
        "name": name,
        "surname": surname,
        "date_of_birth": date_of_birth.isoformat(),
        "swag_level": swag_level,
        "password": password,
    }
    try:
        response = requests.post(f"{API_URL}/people", json=payload, timeout=5)
        response.raise_for_status()
        st.success(f"Registered {name} {surname} to the cool list.")
    except requests.exceptions.HTTPError:
        detail = response.json().get("detail", "An error occured while registering.")
        if isinstance(detail, list):
            messages = dict.fromkeys(err["msg"].removeprefix("Value error, ") for err in detail)
            detail = "; ".join(messages)
        st.error(detail)
        #st.error(response.json().get("detail", "An error occurred while adding the person."))
    except requests.exceptions.ConnectionError:
        st.error("Could not connect to the API. Go like... check if it's running or something.")

if st.session_state.get("removed_message"):
    st.success(st.session_state.pop("removed_message"))

@st.dialog("Remove person")
def remove_dialog(person):
    st.write(f"Remove **{person['name']} {person['surname']}** from the cool people list?")
    pwd = st.text_input("Password", type="password", key=f"pwd_{person['id']}")
    if st.button("Confirm", key=f"del_{person['id']}"):
        resp = requests.delete(
            f"{API_URL}/people/{person['id']}",
            json={"password": pwd},
            timeout=5,
        )
        if resp.status_code == 200:
            st.session_state["removed_message"] = "Person removed from the cool people list"
            st.rerun()
        else:
            st.error(resp.json().get("detail", "Could not remove from the list."))

st.subheader("Check out the people who have massive swag")
try:
    people = requests.get(f"{API_URL}/people", timeout=5).json()
    if people:
        header = st.columns([2, 2, 2, 1, 2, 2])
        for col, label in zip(header, ["Name", "Surname", "Date of Birth", "Age", "Swag Level", ""]):
            col.markdown(f"**{label}**")
        for person in people:
            cols = st.columns([2, 2, 2, 1, 2, 2])
            cols[0].write(person["name"])
            cols[1].write(person["surname"])
            cols[2].write(person["date_of_birth"])
            cols[3].write(person["age"])
            cols[4].write(person["swag_level"])
            with cols[5]:
                if st.button("Remove", key=f"remove_btn_{person['id']}"):
                    remove_dialog(person)
    else:
        st.info("No one has had enough swag to be on the list yet.")
except requests.exceptions.ConnectionError:
    st.error("Could not connect to the API. Go like... check if it's running or something.")