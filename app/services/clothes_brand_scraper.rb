require 'ferrum'
require 'json'
require 'date'
require 'rumale'

class BrandScraper
  BRANDS = {
    'Adidas' => 'https://finance.yahoo.com/quote/ADDYY/key-statistics?p=ADDYY',
    'Puma' => 'https://finance.yahoo.com/quote/PUM.DE/key-statistics?p=PUM.DE',
    'Nike' => 'https://finance.yahoo.com/quote/NKE/key-statistics?p=NKE',
    'Under Armour' => 'https://finance.yahoo.com/quote/UAA/key-statistics?p=UAA',
    # 'Asics' => 'https://finance.yahoo.com/quote/7956.T/key-statistics?p=7956.T',
    'Columbia Sportswear' => 'https://finance.yahoo.com/quote/COLM/key-statistics?p=COLM',
    'Skechers' => 'https://finance.yahoo.com/quote/SKX/key-statistics?p=SKX',
    'Vans' => 'https://finance.yahoo.com/quote/DECK/key-statistics?p=DECK',
  }

  def self.scrape_price_sales_data_for_brand(brand)
    url = BRANDS[brand]
    return [] unless url

    begin
      browser = Ferrum::Browser.new(headless: true)
      browser.goto(url)
      sleep 2

      price_sales_data = []

      # Збираємо рядки таблиці, що містять інформацію про ціни/продажі
      rows = browser.css('section[data-testid="qsp-statistics"] .table-container table tbody tr')
      rows.each do |row|
        key = row.css('td:nth-child(1)').first&.text&.strip
        values = row.css('td:nth-child(2) ~ td').map { |td| td.text.strip }

        # Шукаємо рядок з інформацією про "Price/Sales"
        if key == 'Price/Sales'
          dates = browser.css('section[data-testid="qsp-statistics"] .table-container table thead tr th').map { |th| th.text.strip }

          dates.each_with_index do |date, index|
            value = values[index]
            if value && !value.empty? && date != "" && date != 'N/A'
              price_sales_data << { brand: brand, date: date, price_sales: value.to_f }
            end
          end
          break
        end
      end

      browser.quit
      price_sales_data
    rescue => e
      puts "❌ Помилка при парсингу для #{brand}: #{e.message}"
      []
    end
  end

  def self.predict_price_sales(brand_data, brand, future_days = 1095)  # 1095 днів = 3 роки (2024, 2025, 2026)
    dates = []
    price_sales = []

    # Обробка зібраних даних для побудови прогнозу
    brand_data.each do |data|
      begin
        parsed_date = Date.parse(data[:date]) rescue Date.today
        # Якщо дата та ціна коректні, додаємо їх до списку
        if parsed_date && data[:price_sales]
          dates << parsed_date
          price_sales << data[:price_sales]
        else
          price_sales << (price_sales.empty? ? 0 : price_sales.last)
          dates << parsed_date
        end
      rescue => e
        puts "❌ Некоректна дата для #{data[:date]}, використано поточну дату."
        dates << Date.today
        price_sales << (price_sales.empty? ? 0 : price_sales.last)
      end
    end

    return [] if dates.length < 2 || price_sales.length < 2

    # Підготовка даних для прогнозування
    first_date = dates.first
    x = dates.map { |date| [(date - first_date).to_i] }
    y = price_sales

    # Лінійна регресія для прогнозування
    model = Rumale::LinearModel::LinearRegression.new
    model.fit(x, y)

    # Генерація майбутніх дат для прогнозу
    future_dates = (1..future_days).map { |d| d }
    predicted_values = model.predict(future_dates.map { |day| [day] })

    # Повернення прогнозованих значень
    future_dates.map.with_index do |day, index|
      # Початок з 1 січня 2024 року
      projected_date = Date.new(2024, 1, 1) + day
      { brand: brand, date: projected_date.to_s, predicted_price_sales: predicted_values[index].round(2) }
    end
  end

  def self.scrape_and_predict_for_all_brands
    all_predictions = []

    # Збираємо дані для кожного бренду і генеруємо прогноз
    BRANDS.keys.each do |brand|
      brand_data = scrape_price_sales_data_for_brand(brand)
      next if brand_data.empty?

      predicted_data = predict_price_sales(brand_data, brand, 1095)  # Прогноз на 3 роки
      all_predictions.concat(predicted_data) unless predicted_data.empty?
    end

    # Записуємо результати в JSON файл
    if all_predictions.any?
      File.open("predicted_price_sales_all_brands_future.json", "w") do |f|
        f.write(JSON.pretty_generate(all_predictions))
      end
      puts "✅ Прогнозування для всіх брендів на майбутнє збережено у 'predicted_price_sales_all_brands_future.json'"
    else
      puts "❌ Не вдалося здійснити прогноз для жодного бренду."
    end
  end
  def self.scrape_and_save_data_for_all_brands
    all_data = []

    # Збираємо дані для кожного бренду
    BRANDS.keys.each do |brand|
      brand_data = scrape_price_sales_data_for_brand(brand)
      next if brand_data.empty?

      all_data << {
        brand: brand,
        data: brand_data
      }
    end

    # Збереження даних у JSON файл
    if all_data.any?
      File.open("brand_sales_data.json", "w") do |f|
        f.write(JSON.pretty_generate(all_data))
      end
      puts "✅ Дані про продажі збережено у 'brand_sales_data.json'"
    else
      puts "❌ Не вдалося зібрати дані для жодного бренду."
    end
  end
end

# Запуск процесу парсингу та прогнозування
BrandScraper.scrape_and_predict_for_all_brands
