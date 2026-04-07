# Service to fetch weather data from OpenWeatherMap API based on zip code
class WeatherForecastService
  include ActiveModel::Validations

  VALID_WEATHER_RESPONSE      = Data.define(:valid?, :main, :weather, :wind)
  INVALID_WEATHER_RESPONSE    = Data.define(:valid?, :errors)
  BASE_URL                    = ENV.fetch("OPENWEATHERMAP_BASE_URL")
  API_KEY                     = ENV.fetch("OPENWEATHERMAP_API_KEY")
  HTTP_ERROR_STATUS_THRESHOLD = 300

  validates :zip_code,
            presence: true,
            format: { with: /\A\d{5,8}\z/, message: "must be 5-8 digits" },
            allow_blank: true

  class << self
    def call(zip_code:)
      new(zip_code).call
    end
  end

  def initialize(zip_code)
    @zip_code = zip_code
  end

  def call
    return success_response(nil) if zip_code.blank?
    return error_response(errors.full_messages) unless valid?

    response = HTTParty.get(endpoint)

    return failure_response(response) if response.code >= HTTP_ERROR_STATUS_THRESHOLD
    success_response(response)
  rescue => e
    Rails.logger.error("Error fetching weather data: #{e.message}")
    error_response([e.message])
  end

  private

  attr_reader :zip_code

  def endpoint
    query = URI.encode_www_form(zip: zip_code, appid: API_KEY)
    URI.join(BASE_URL, "/data/2.5/weather?#{query}")
  end

  def success_response(response)
    VALID_WEATHER_RESPONSE.new(valid?: true,
                               main: response&.dig("main"),
                               weather: response&.dig("weather"),
                               wind: response&.dig("wind"))
  end

  def error_response(errors)
    INVALID_WEATHER_RESPONSE.new(valid?: false, errors: errors)
  end

  def failure_response(response)
    INVALID_WEATHER_RESPONSE.new(valid?: false, errors: [response.dig("message")])
  end
end
