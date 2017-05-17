FROM ruby:2.4.1

RUN gem install jekyll bundler

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install --jobs 3

CMD bundle exec jekyll serve -H 0.0.0.0