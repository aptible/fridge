FROM ruby:3.4

WORKDIR /app

COPY Gemfile /app/Gemfile
COPY fridge.gemspec /app/fridge.gemspec
COPY lib/ /app/lib

RUN bundle install

COPY spec/ /app/spec
COPY .rspec /app/.rspec
COPY Rakefile /app/Rakefile

CMD ["true"]
