FROM debian:stretch

RUN apt-get -y -qq update && apt-get -y -qq install software-properties-common

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    debhelper \
    devscripts \
    git-buildpackage \
    git \
    gnupg \
    lsb-release \
    locales \
    make \
    pristine-tar \
    python \
    python-pip \
    python-setuptools \
    wget \
    zlib1g-dev \
    ruby \
    ruby-dev \
    default-libmysqlclient-dev \
    libxml2-dev \
    libxml2 \
    libxslt1-dev \
    liblzma-dev \
    patch \
    pkg-config \
    fakeroot \
    libssl-dev

RUN gem install bundler && \
    pip install awscli

RUN groupadd -r ecsdeploy -g 113 \
    && useradd -u 113 -r -g ecsdeploy -d /srv/cloudcontrol -s /sbin/nologin -c "Docker ecsdeploy" ecsdeploy \
    && mkdir -m 755 -p /srv/ecsdeploy

COPY . /srv/ecsdeploy

WORKDIR /srv/ecsdeploy

RUN bundle install --path vendor/bundle && \
    chown -R ecsdeploy:ecsdeploy /srv/ecsdeploy && \
    chmod -R 755 /srv/ecsdeploy

USER ecsdeploy

CMD ["hostname"]
