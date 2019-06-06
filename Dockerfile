FROM ruby:2.6.3

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install --jobs 3

CMD bundle exec jekyll serve -H 0.0.0.0
