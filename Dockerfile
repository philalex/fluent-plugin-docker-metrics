FROM ubuntu:14.04
MAINTAINER Philippe ALEXANDRE <alexandre.philippe+github@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y git
RUN apt-get install -y ruby1.9.1

RUN mkdir /src
WORKDIR /src
RUN git clone https://github.com/philalex/fluent-plugin-docker-metrics.git
WORKDIR /gem
CMD ["gem", "build", "/src/fluent-plugin-docker-metrics/fluent-plugin-docker-metrics.gemspec"]
