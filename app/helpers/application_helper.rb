module ApplicationHelper
  def openweather_temp_suffix
    WeatherForecastService::UNITS == "imperial" ? "°F" : "°C"
  end

  def openweather_wind_suffix
    WeatherForecastService::UNITS == "imperial" ? "mph" : "m/s"
  end
end
