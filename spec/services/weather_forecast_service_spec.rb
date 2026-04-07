require "rails_helper"

RSpec.describe WeatherForecastService do
  describe "#call" do
    let(:us_zip) { "10001" }

    context "when the zip code is valid but the API returns an error payload" do
      let(:http_response) { double("http_response", code: 404, body: { "message" => "city not found" }.to_json) }

      before { allow(HTTParty).to receive(:get).and_return(http_response) }

      it "returns an unsuccessful response with the API message" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["city not found"])
      end

      it "calls the weather API once" do
        described_class.call(zip_code: us_zip)
        expect(HTTParty).to have_received(:get).once
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
      let(:http_response) { double("http_response", code: 400, body: { "message" => "Bad Request" }.to_json) }

      before { allow(HTTParty).to receive(:get).and_return(http_response) }

      it "returns an unsuccessful response" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["Bad Request"])
      end
    end

    context "when the API returns 200" do
      let(:parsed) do
        {
          "main" => { "temp" => 70, "temp_min" => 65, "temp_max" => 75 },
          "weather" => [{ "description" => "Sunny" }],
          "wind" => { "speed" => 10 }
        }
      end
      let(:http_response) { double("http_response", code: 200, body: parsed.to_json) }

      before { allow(HTTParty).to receive(:get).and_return(http_response) }

      it "maps main, weather, and wind from the payload" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(true)
        expect(response.main).to eq({ "temp" => 70, "temp_min" => 65, "temp_max" => 75 })
        expect(response.weather).to eq([{ "description" => "Sunny" }])
        expect(response.wind).to eq({ "speed" => 10 })
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

    context "with an 8-digit postal code" do
      let(:parsed) do
        { "main" => { "temp" => 25 }, "weather" => [{ "description" => "clouds" }], "wind" => { "speed" => 3 } }
      end
      let(:http_response) { double("http_response", code: 200, body: parsed.to_json) }

      before { allow(HTTParty).to receive(:get).and_return(http_response) }

      it "requests current weather using the postal code in the zip query param" do
        described_class.call(zip_code: "01310100")
        expect(HTTParty).to have_received(:get).once.with(
          satisfy { |uri| uri.to_s.include?("/data/2.5/weather") && uri.to_s.include?("zip=01310100") }
        )
      end
    end
  end
end
