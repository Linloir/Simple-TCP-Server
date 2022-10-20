# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS compile

# Resolve app dependencies.
WORKDIR /lchatserver
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart compile exe bin/tcp_server.dart -o bin/tcp_server

FROM ubuntu:latest

RUN apt-get update && apt-get -y install libsqlite3-0 libsqlite3-dev

# Copy the previously built executable into the scratch layer
RUN mkdir /lchatserver
COPY --from=compile /runtime/ /lchatserver/
COPY --from=compile /lchatserver/bin/tcp_server /lchatserver/bin/

# Start server.
EXPOSE 20706
WORKDIR /lchatserver/bin
CMD ["/lchatserver/bin/tcp_server"]