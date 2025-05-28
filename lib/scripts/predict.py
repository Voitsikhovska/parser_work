import sys
import json
import pandas as pd
import numpy as np

try:
    # Отримуємо JSON
    data = json.loads(sys.argv[1])

    def generate_forecast(df):

        df["date"] = pd.to_datetime(df["date"])
        df = df.sort_values("date")

        current_value = df["price_sales"].iloc[-1]
        current_date = df["date"].max()

        # Вираховуємо середню зміну ціни між попередніми періодами
        if len(df) > 1:
            past_changes = np.diff(df["price_sales"])
            avg_change = np.mean(past_changes)
            std_dev = np.std(past_changes)  # Стандартне відхилення
        else:
            avg_change = 0.05 * current_value
            std_dev = 0.02 * current_value  # Запасне значення коливань

        # **Генеруємо минулі передбачення**
        past_dates = pd.date_range(end=current_date, periods=4, freq="3M")[:-1]  # 3 попередні періоди
        past_predictions = []
        last_value = current_value

        for date in reversed(past_dates):
            random_variation = np.random.uniform(-std_dev, std_dev)  # Додаємо випадкові коливання
            new_value = last_value - avg_change + random_variation  # Генеруємо попередні значення
            new_value = max(0, new_value)
            past_predictions.insert(0, {"date": str(date.date()), "predicted_price_sales": round(new_value, 2)})
            last_value = new_value

        # **Генеруємо майбутні передбачення**
        future_dates = pd.date_range(start=current_date, periods=4, freq="3M")[1:]  # 3 майбутні періоди
        future_predictions = []
        last_value = current_value

        for date in future_dates:
            random_variation = np.random.uniform(-std_dev, std_dev)  # Випадкові стрибки
            new_value = last_value + avg_change + random_variation
            new_value = max(0, new_value)
            future_predictions.append({"date": str(date.date()), "predicted_price_sales": round(new_value, 2)})
            last_value = new_value

        # Додаємо поточне значення у прогнозовані дані
        future_predictions.insert(0, {"date": str(current_date.date()), "predicted_price_sales": round(current_value, 2)})
        past_predictions.append({"date": str(current_date.date()), "predicted_price_sales": round(current_value, 2)})

        return past_predictions, future_predictions

    # Генеруємо прогноз для Adidas, Puma та Hugo Boss
    ads_sg_forecast_past, ads_sg_forecast_future = generate_forecast(pd.DataFrame(data["ads_sg"]))
    pum_de_forecast_past, pum_de_forecast_future = generate_forecast(pd.DataFrame(data["pum_de"]))
    boss_de_forecast_past, boss_de_forecast_future = generate_forecast(pd.DataFrame(data["boss_de"]))

    # Формуємо вихідний JSON
    output = {
        "ads_sg_past": ads_sg_forecast_past,
        "ads_sg_future": ads_sg_forecast_future,
        "pum_de_past": pum_de_forecast_past,
        "pum_de_future": pum_de_forecast_future,
        "boss_de_past": boss_de_forecast_past,
        "boss_de_future": boss_de_forecast_future
    }

    print(json.dumps(output))

except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(1)
