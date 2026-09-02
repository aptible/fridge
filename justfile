init:
  rm Gemfile.lock || true
  docker compose build

test:
  docker compose run fridge bundle exec rspec

lint:
  docker compose run fridge bundle exec rubocop

pretty:
  docker compose run fridge bundle exec rubocop -a

shell:
  docker compose run fridge bash
