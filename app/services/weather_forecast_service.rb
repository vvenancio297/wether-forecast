# Service to fetch weather data from OpenWeatherMap API based on zip code.
class WeatherForecastService
  include ActiveModel::Validations

  VALID_WEATHER_RESPONSE      = Data.define(:valid?, :main, :weather, :wind, :read_from_cache)
  INVALID_WEATHER_RESPONSE    = Data.define(:valid?, :errors, :read_from_cache)
  BASE_URL                    = ENV.fetch("OPENWEATHERMAP_BASE_URL")
  API_KEY                     = ENV.fetch("OPENWEATHERMAP_API_KEY")
  UNITS                       = ENV.fetch("OPENWEATHERMAP_UNITS", "imperial")
  HTTP_ERROR_STATUS_THRESHOLD = 300

  validates :zip_code,
            presence: true,
            format: { with: /\A\d{5}\z/, message: "must be 5 digits" },
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
    return error_response(errors.full_messages, false) unless valid?

    cached_response = read_cache
    if cached_response.present?
      return build_response_object(cached_response, true)
    end

    response = HTTParty.get(current_weather_url)
    response_object = build_response_object(response, false)

    if response_object.valid? && response_object.main.present?
      payload = response_object.to_h.except(:read_from_cache).merge(status_code: response.code)
      cache_response(payload)
    end

    response_object
  rescue => e
    Rails.logger.error("Error fetching weather data: #{e.message}")
    error_response([e.message], false)
  end

  private

  attr_reader :zip_code

  def cache_key
    "weather_forecast/#{zip_code}/#{UNITS}"
  end

  def read_cache
    Rails.cache.read(cache_key)
  end

  def cache_response(payload)
    Rails.cache.write(cache_key, payload, expires_in: 30.minutes)
  end

  def empty_success
    VALID_WEATHER_RESPONSE.new(valid?: true, main: nil, weather: nil, wind: nil, read_from_cache: false)
  end

  def query_params
    URI.encode_www_form(zip: zip_code, units: UNITS, appid: API_KEY)
  end

  def current_weather_url
    URI.join(BASE_URL, "/data/2.5/weather?#{query_params}")
  end

  def build_response_object(response, read_from_cache = false)
    status_code, body = extract_status_and_body(response)

    if status_code.to_i >= HTTP_ERROR_STATUS_THRESHOLD
      failure_response(body, read_from_cache)
    else
      build_success(body, read_from_cache)
    end
  end

  def extract_status_and_body(response)
    if response.is_a?(Hash)
      h = response.with_indifferent_access
      status = h[:status_code]
      [status, h.except(:status_code)]
    else
      [response.code, response.body]
    end
  end

  def build_success(body, read_from_cache)
    current_json = parsed_body(body)

    VALID_WEATHER_RESPONSE.new(valid?: true,
                               main: current_json["main"],
                               weather: current_json["weather"],
                               wind: current_json["wind"],
                               read_from_cache: read_from_cache)
  end

  def parsed_body(body)
    return body.with_indifferent_access if body.is_a?(Hash)

    JSON.parse(body)
  rescue JSON::ParserError
    {}
  end

  def failure_response(body, read_from_cache)
    message = parsed_body(body)["message"].presence || "Weather data unavailable"
    INVALID_WEATHER_RESPONSE.new(valid?: false, errors: [message], read_from_cache: read_from_cache)
  end

  def error_response(errors, read_from_cache)
    INVALID_WEATHER_RESPONSE.new(valid?: false, errors: errors, read_from_cache: read_from_cache)
  end
end
