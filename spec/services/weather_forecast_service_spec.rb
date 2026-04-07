require "rails_helper"

RSpec.describe WeatherForecastService do
  describe "#call" do
    let(:us_zip) { "10001" }

    context "when the zip code is valid but the API returns an error payload" do
      let(:parsed_error) { { "message" => "city not found" } }
      let(:http_response) { double("http_response", code: 404) }

      before do
        allow(http_response).to receive(:dig) { |*keys| parsed_error.dig(*keys) }
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "returns an unsuccessful response with the API message" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["city not found"])
      end
    end

    context "when the zip code is blank" do
      it "returns a successful response with empty payload fields" do
        response = described_class.call(zip_code: "")
        expect(response.valid?).to be(true)
        expect(response.main).to be_nil
        expect(response.weather).to be_nil
        expect(response.wind).to be_nil
      end
    end

    context "when the zip code is not only digits" do
      it "returns validation errors" do
        response = described_class.call(zip_code: "10001a")
        expect(response.valid?).to be(false)
        expect(response.errors).to include(/must be 5-8 digits/)
      end
    end

    context "when the zip code is not 5-8 digits" do
      it "returns validation errors" do
        response = described_class.call(zip_code: "1000123456789")
        expect(response.valid?).to be(false)
        expect(response.errors).to include(/must be 5-8 digits/)
      end
    end

    context "when the API returns a non-200 status code" do
      let(:parsed_error) { { "message" => "Bad Request" } }
      let(:http_response) { double("http_response", code: 400) }

      before do
        allow(http_response).to receive(:dig) { |*keys| parsed_error.dig(*keys) }
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "returns an unsuccessful response" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["Bad Request"])
      end
    end

    context "when the API returns a 200 status code" do
      let(:response_body) do
        { main: { temp: 70 }, weather: [{ description: "Sunny" }], wind: { speed: 5 } }.to_json
      end
      let(:parsed) { JSON.parse(response_body) }
      let(:http_response) { double("http_response", code: 200) }

      before do
        allow(http_response).to receive(:dig) { |*keys| parsed.dig(*keys) }
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "maps main, weather, and wind from the payload" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(true)
        expect(response.main).to eq({ "temp" => 70 })
        expect(response.weather).to eq([{ "description" => "Sunny" }])
        expect(response.wind).to eq({ "speed" => 5 })
      end
    end

    context "when the API raises" do
      before do
        allow(HTTParty).to receive(:get).and_raise(StandardError.new("API Error"))
      end

      it "returns an unsuccessful response with the exception message" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["API Error"])
      end
    end
  end
end
