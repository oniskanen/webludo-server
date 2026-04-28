# LOCAL DEVELOPMENT ONLY.
# Production deploys use mix release + systemd on an exe.dev VM —
# see deploy/README.md. This image is convenient for `docker compose
# -f docker-compose.dev.yml up` and is not on the production path.
# The Elixir version pinned here is intentionally not kept in sync
# with the production toolchain in .tool-versions.
FROM elixir:1.10

RUN apt-get update && \
  apt-get install -y postgresql-client

# Create app directory and copy the Elixir projects into it
RUN mkdir /app
COPY . /app
WORKDIR /app

RUN mix local.hex --force
RUN mix local.rebar --force

# Compile the project
RUN mix do compile

CMD ["/app/entrypoint.sh"]