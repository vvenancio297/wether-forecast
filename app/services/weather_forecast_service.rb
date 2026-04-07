# Service to fetch weather data from OpenWeatherMap API based on zip / postal code.
class WeatherForecastService
  include ActiveModel::Validations

  VALID_WEATHER_RESPONSE      = Data.define(:valid?, :main, :weather, :wind)
  INVALID_WEATHER_RESPONSE    = Data.define(:valid?, :errors)
  BASE_URL                    = ENV.fetch("OPENWEATHERMAP_BASE_URL")
  API_KEY                     = ENV.fetch("OPENWEATHERMAP_API_KEY")
  UNITS                       = ENV.fetch("OPENWEATHERMAP_UNITS", "imperial")
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
    return empty_success if zip_code.blank?
    return error_response(errors.full_messages) unless valid?

    response = HTTParty.get(current_weather_url)
    return failure_response(response) if response.code >= HTTP_ERROR_STATUS_THRESHOLD

    build_success(response)
  rescue => e
    Rails.logger.error("Error fetching weather data: #{e.message}")
    error_response([e.message])
  end

  private

  attr_reader :zip_code

  def empty_success
    VALID_WEATHER_RESPONSE.new(valid?: true, main: nil, weather: nil, wind: nil)
  end

  def query_params
    URI.encode_www_form(zip: zip_code, units: UNITS, appid: API_KEY)
  end

  def current_weather_url
    URI.join(BASE_URL, "/data/2.5/weather?#{query_params}")
  end

  def build_success(response)
    current_json = parsed_body(response)

    VALID_WEATHER_RESPONSE.new(valid?: true,
                               main: current_json["main"],
                               weather: current_json["weather"],
                               wind: current_json["wind"])
  end

  def parsed_body(response)
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  def failure_response(response)
    message = parsed_body(response)["message"].presence || "Weather data unavailable"
    INVALID_WEATHER_RESPONSE.new(valid?: false, errors: [message])
  end

  def error_response(errors)
    INVALID_WEATHER_RESPONSE.new(valid?: false, errors: errors)
  end
end
