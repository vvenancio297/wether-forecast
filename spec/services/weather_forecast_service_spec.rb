require "rails_helper"

RSpec.describe WeatherForecastService do
  describe "#call" do
    let(:us_zip) { "10001" }

    context "when the zip code is valid but the API returns an error payload" do
      let(:http_response) { double("http_response", code: 404, body: { "message" => "city not found" }.to_json) }

      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "returns an unsuccessful response with the API message" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["city not found"])
      end

      it "calls the weather API once" do
        described_class.call(zip_code: us_zip)
        expect(HTTParty).to have_received(:get).once
      end

      it "does not write to the cache" do
        described_class.call(zip_code: us_zip)
        expect(Rails.cache).not_to have_received(:write)
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
        expect(response.errors).to include(/must be 5 digits/)
      end
    end

    context "when the zip code is not exactly 5 digits" do
      it "rejects too few digits" do
        response = described_class.call(zip_code: "1001")
        expect(response.valid?).to be(false)
        expect(response.errors).to include(/must be 5 digits/)
      end

      it "rejects too many digits" do
        response = described_class.call(zip_code: "100012")
        expect(response.valid?).to be(false)
        expect(response.errors).to include(/must be 5 digits/)
      end
    end

    context "when the API returns a non-200 status code" do
      let(:http_response) { double("http_response", code: 400, body: { "message" => "Bad Request" }.to_json) }

      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "returns an unsuccessful response" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["Bad Request"])
      end

      it "does not write to the cache" do
        described_class.call(zip_code: us_zip)
        expect(Rails.cache).not_to have_received(:write)
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

      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "maps main, weather, and wind from the payload" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(true)
        expect(response.main).to eq({ "temp" => 70, "temp_min" => 65, "temp_max" => 75 })
        expect(response.weather).to eq([{ "description" => "Sunny" }])
        expect(response.wind).to eq({ "speed" => 10 })
      end

      it "caches with a key that includes ZIP and units" do
        described_class.call(zip_code: us_zip)
        expect(Rails.cache).to have_received(:write).with(
          "weather_forecast/#{us_zip}/#{described_class::UNITS}",
          kind_of(Hash),
          hash_including(expires_in: 30.minutes)
        )
      end
    end

    context "when the API raises" do
      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(HTTParty).to receive(:get).and_raise(StandardError.new("API Error"))
      end

      it "returns an unsuccessful response with the exception message" do
        response = described_class.call(zip_code: us_zip)
        expect(response.valid?).to be(false)
        expect(response.errors).to eq(["API Error"])
      end

      it "does not write to the cache" do
        described_class.call(zip_code: us_zip)
        expect(Rails.cache).not_to have_received(:write)
      end
    end

    context "when calling the weather API for a US ZIP" do
      let(:parsed) do
        { "main" => { "temp" => 72 }, "weather" => [{ "description" => "clear" }], "wind" => { "speed" => 5 } }
      end
      let(:http_response) { double("http_response", code: 200, body: parsed.to_json) }

      before do
        allow(Rails.cache).to receive(:read).and_return(nil)
        allow(Rails.cache).to receive(:write)
        allow(HTTParty).to receive(:get).and_return(http_response)
      end

      it "puts the zip in the query string" do
        described_class.call(zip_code: "90210")
        expect(HTTParty).to have_received(:get).once.with(
          satisfy { |uri| uri.to_s.include?("/data/2.5/weather") && uri.to_s.include?("zip=90210") }
        )
      end
    end
  end
end
