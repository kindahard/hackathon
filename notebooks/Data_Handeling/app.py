import streamlit as st
import pandas as pd
import numpy as np
import joblib

# Load the model you trained in Ai_Model.ipynb
model = joblib.load('listing_model.pkl')

st.title("💰 Smart Price Predictor")

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
    # Match the features exactly as defined in your Ai_Model pipeline
    data = pd.DataFrame({
        'room_type': [room], 'city': [city], 'max_guests': [guests],
        'num_bedrooms': [bedrooms], 'distance_city_center': [dist_center],
        'cleanliness_score': [clean], 'Monthly_Average_Net_salary': [salary],
        'Meal_at_Inexpensive_Restaurant': [meal],
        'Taxi_price_per_Km': [2.0], 'Monthly_Basic_Utilities': [250.0]
    })
    
    # Predict and reverse log transform
    prediction_log = model.predict(data)[0]
    final_price = np.expm1(prediction_log)
    
    st.success(f"### Predicted Price: ${final_price:.2f}")