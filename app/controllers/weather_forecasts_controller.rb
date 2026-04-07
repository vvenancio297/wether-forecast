class WeatherForecastsController < ApplicationController
  def index
    @weather_forecast = WeatherForecastService.call(zip_code: params[:zip_code])
  end
end
