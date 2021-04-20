FROM ubuntu:16.04

ENV RUBY_VERSION 1.9.2-p330
ENV RUBY_SHA1SUM d25dca1adf186a1be7dcf12a48ea4c7abadfcf12

RUN BUILD_DIR="/tmp/ruby-build" \
 && apt-get update \
 && apt-get -y install wget build-essential zlib1g-dev libssl-dev \
    libreadline6-dev libyaml-dev tzdata \
 && mkdir -p "$BUILD_DIR" \
 && cd "$BUILD_DIR" \
 && wget -q "http://cache.ruby-lang.org/pub/ruby/ruby-${RUBY_VERSION}.tar.gz" \
 && echo "${RUBY_SHA1SUM}  ruby-${RUBY_VERSION}.tar.gz" | sha1sum -c - \
 && tar xzf "ruby-${RUBY_VERSION}.tar.gz" \
 && cd "ruby-${RUBY_VERSION}" \
 && ./configure --enable-shared --prefix=/usr \
 && make \
 && make install \
 && cd / \
 && rm -r "$BUILD_DIR" \
 && rm -rf /var/lib/apt/lists/*

RUN gem update --system
RUN gem install --force bundler

WORKDIR /app
ENV DEBIAN-FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y unzip unrar p7zip-full xz-utils
RUN apt-get install -y libxml2-dev libxslt1-dev zlib1g-dev libbz2-dev libcurl4-openssl-dev
RUN apt-get install -y git vim

# patch in sni support
COPY 0001-patch-ruby-sni-support.patch ./
RUN cd /usr/lib/ruby/1.9.1; patch -p2 < /app/0001-patch-ruby-sni-support.patch

COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN bundle install

ARG USER_ID
RUN useradd --shell /bin/bash -u ${USER_ID:-1000} -o -c "" -m user
ENV HOME=/home/user
#uncomment to lower privs
#USER user

COPY . /app
