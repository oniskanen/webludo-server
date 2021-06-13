# Linode VM runs Debian 10 (Buster)
FROM debian:10

ENV REFRESHED_AT=2021-06-13 \
    LANG=C.UTF-8 \
    HOME=/opt/build \
    TERM=xterm

WORKDIR /opt/build

RUN \
  apt-get update -y && \
  apt-get install -y git wget vim locales gnupg && \
  locale-gen en_US.UTF-8 && \
  wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && \
  dpkg -i erlang-solutions_2.0_all.deb && \
  rm erlang-solutions_2.0_all.deb && \
  apt-get update -y && \
  apt-get install -y erlang elixir


CMD ["/bin/bash"]