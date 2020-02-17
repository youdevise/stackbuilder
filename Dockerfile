ARG ruby_version=2.1.10

FROM ruby:${ruby_version}-alpine as build

RUN apk add --no-cache make gcc libc-dev

WORKDIR /build
COPY Gemfile Gemfile.lock ./

WORKDIR /build/vendor/bundle/ruby
RUN bundle install --no-cache --deployment --without development && \
      rm -rf ./*/cache ./*/gems/*/spec/* ./*/gems/*/tests/*


FROM ruby:${ruby_version}-alpine

ARG kubectl_version=1.16.2

ADD https://storage.googleapis.com/kubernetes-release/release/v${kubectl_version}/bin/linux/amd64/kubectl /usr/local/bin/kubectl

RUN chmod +x /usr/local/bin/kubectl && \
      addgroup -S stacks && \
      adduser -S stacks -G stacks && \
      apk add --no-cache git

USER stacks
WORKDIR /home/stacks

COPY --from=build /build /home/stacks
COPY --from=build /usr/local/bundle /usr/local/bundle

COPY bin /usr/local/bin/
COPY lib /usr/local/lib/site_ruby/timgroup
COPY mcollective_plugins /usr/share/mcollective/plugins/mcollective

ENV RUBYLIB=/usr/local/lib/site_ruby/timgroup
ENTRYPOINT ["bundle", "exec", "/usr/local/bin/stacks"]