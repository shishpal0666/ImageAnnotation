# Stage 1: Build
FROM debian:latest AS build-env
RUN apt-get update && apt-get install -y curl git unzip
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter config --enable-web
WORKDIR /app
COPY . .
RUN flutter build web

# Stage 2: Serve
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
