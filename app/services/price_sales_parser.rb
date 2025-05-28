class PriceSalesParser
  def self.scrape_price_sales(url)
    html = URI.open(url, "User-Agent" => "Mozilla/5.0").read
    doc = Nokogiri::HTML(html)

    price_sales_text = doc.at('td:contains("Price/Sales (ttm)")')&.next_element&.text
    price_sales = parse_price(price_sales_text)

    {
      date: Date.today.strftime("%Y-%m-%d"),
      price_sales: price_sales
    }
  end

  def self.parse_price(text)
    return nil if text.blank?
    text.gsub(/[^\d.]/, "").to_f
  end
end
