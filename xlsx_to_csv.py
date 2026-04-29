import pandas as pd

files = {
    "DRIVER.xlsx": "tmp_drivers.csv",
    "Verified Extracted Data.xlsx": "tmp_misc.csv",
    "Verified_Chatgpt_booking_data.xlsx": "tmp_bookings.csv",
    "Verified_Chatgpt_car_data.xlsx": "tmp_vehicles.csv"
}

for xlsx, csv in files.items():
    print(f"Converting {xlsx} -> {csv}")
    df = pd.read_excel(xlsx)
    df.to_csv(csv, index=False)

print("✅ Conversion completed")
