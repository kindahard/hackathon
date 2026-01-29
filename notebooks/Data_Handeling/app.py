import streamlit as st
import pandas as pd
import numpy as np
import joblib

# Load the model you trained in Ai_Model.ipynb
model = joblib.load('listing_model.pkl')

st.title("Price Predictor by ElMahro2")

with st.form("input_form"):
    col1, col2 = st.columns(2)
    with col1:
        city = st.text_input("City", "London")
        room = st.selectbox("Room Type", ["Entire home/apt", "Private room", "Shared room"])
        guests = st.number_input("Max Guests", 1, 16, 2)
        bedrooms = st.number_input("Bedrooms", 1, 10, 1)
    
    with col2:
        salary = st.number_input("City Avg Salary ($)", value=3500.0)
        meal = st.number_input("Meal Price ($)", value=15.0)
        dist_center = st.slider("Distance to Center (km)", 0.0, 20.0, 2.5)
        clean = st.slider("Cleanliness Score", 0.0, 10.0, 9.5)
    
    submit = st.form_submit_button("Predict Price")

if submit:
    user_input = {
        'room_type': room,
        'city': city,
        'max_guests': guests,
        'num_bedrooms': bedrooms,
        'distance_city_center': dist_center,
        'cleanliness_score': clean,
        'Monthly_Average_Net_salary': salary,
        'Meal_at_Inexpensive_Restaurant': meal,
        'Taxi_price_per_Km': 2.0,
        'Monthly_Basic_Utilities': 250.0,
    }

    preprocessor = model.named_steps['preprocessor']

    # 🔹 columns by type
    categorical_cols = []
    numerical_cols = []

    for name, transformer, cols in preprocessor.transformers_:
        if transformer == 'drop':
            continue
        if hasattr(transformer, 'categories_'):  # OneHotEncoder
            categorical_cols.extend(cols)
        else:
            numerical_cols.extend(cols)

    # 🔹 fill missing categorical
    for col in categorical_cols:
        if col not in user_input:
            user_input[col] = "Unknown"

    # 🔹 fill missing numeric
    for col in numerical_cols:
        if col not in user_input:
            user_input[col] = 0.0

    data = pd.DataFrame([user_input])

    prediction_log = model.predict(data)[0]
    final_price = np.expm1(prediction_log)

    st.success(f"### Predicted Price: ${final_price:.2f}")
