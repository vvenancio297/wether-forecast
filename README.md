# Weather forecast

A small **Ruby on Rails** app that looks up **current weather** from [OpenWeather](https://openweathermap.org/) for a **US ZIP code** (exactly **5 digits**). It shows the current temperature (with low/high when the API provides them), conditions, and wind via the [current weather API](https://openweathermap.org/current#zip) (`zip`, `units`, `appid`).

Stack highlights: Rails 8, **Propshaft**, **importmap** (with vendored Bootstrap JS), **Bootstrap** styles via **cssbundling** (`yarn build:css` / `bin/dev` for watch), **HTTParty** for HTTP, and **RSpec** for tests.

**Ruby:** 3.4.3 (see `.ruby-version`).

## Setup

- Ruby and Bundler
- **PostgreSQL** (configured in `config/database.yml`)
- **Node + Yarn** for CSS compilation

```bash
cp .env.sample .env
# Set OPENWEATHERMAP_API_KEY and optionally OPENWEATHERMAP_BASE_URL / OPENWEATHERMAP_UNITS

bundle install
yarn install
yarn build:css
bin/rails db:prepare
```

Run the app:

```bash
bin/rails server
# or CSS watch + server together:
bin/dev
```

Open **`/weather_forecasts`** in the browser (there is no `root` route set yet; add e.g. `root "weather_forecasts#index"` in `config/routes.rb` if you want `/`).

## Tests

```bash
bundle exec rspec
```

## Future features

### Extended forecast

The app intentionally uses only **current weather** today. A natural next step is a **multi-day or 3-hour-step outlook** using OpenWeather’s **[5 day / 3 hour forecast](https://openweathermap.org/forecast5)**

### Dockerize the app

There is already a **`Dockerfile`** (Rails/Kamal-style) in the repo; a fuller **container workflow** could still be added or tightened up:

- **`docker compose`** (or similar) for **local development**: web + **PostgreSQL**, mounted code where useful, env file for `OPENWEATHERMAP_*` and `RAILS_MASTER_KEY`.
- **Asset pipeline in the image:** run **`yarn install`** and **`yarn build:css`** during the Docker build so `application.css` exists without a manual host step.
- **Document** one-liner commands: build, `db:prepare`, run server, and how production secrets differ from dev.

That makes onboarding and deployment reproducible without installing Ruby/Node/Postgres directly on the machine.
