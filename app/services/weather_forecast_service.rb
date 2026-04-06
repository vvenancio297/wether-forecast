class WeatherForecastService
  class << self
    def call(zip_code)
      new(zip_code).call
    end
  end

  def initialize(zip_code)
    @zip_code = zip_code
  end

  def call
  end

  private

  attr_reader :zip_code
end
