#
# This Dockerfile is for creating an image to bootstrap a container within which one or more
# Silverpeas projects in developement can be built. It is expected the source code is shared
# between the host (in which the IDE is running) and the container (in which the build is performed).
#
# By using such a container, we ensure the build is reproductible and doesn't depend on the
# environment context specific to the developer's host.
#
FROM ubuntu:bionic

LABEL name="Silverpeas Build" description="An image to build a Silverpeas project" vendor="Silverpeas" version=6.1-rc2
MAINTAINER Miguel Moquillon "miguel.moquillon@silverpeas.org"

ENV TERM=xterm

# Parameters whose values are required for the tests to succeed
ARG DEFAULT_LOCALE=fr_FR.UTF-8
ARG MAVEN_VERSION=3.6.1
ARG MAVEN_SHA=b4880fb7a3d81edd190a029440cdf17f308621af68475a4fe976296e71ff4a4b546dd6d8a58aaafba334d309cc11e638c52808a4b0e818fc0fd544226d952544
ARG WILDFLY_VERSION=15.0.1
ARG JAVA_VERSION=8

# Because the source code is shared between the host and the container, it is required the identifier
# of the owner and of its group are the same between this two environments. By default, they are both set at 1000.
# The user in the Docker container is also in the group users (id 100 by default)
ARG USER_ID=1000
ARG GROUP_ID=1000

COPY src/maven-deps.zip /tmp/

RUN apt-get update && apt-get install -y \
    iputils-ping \
    vim \
    curl \
    git \
    openssh-client \
    gnupg \
    locales \
    procps \
    net-tools \
    zip \
    unzip \
    openjdk-${JAVA_VERSION}-jdk \
    ffmpeg \
    imagemagick \
    ghostscript \
    libreoffice-writer \
    libreoffice-calc \
    libreoffice-impress \
    gpgv \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates -f \
  && groupadd -g ${GROUP_ID} silveruser \
  && useradd -u ${USER_ID} -g ${GROUP_ID} -G users -d /home/silveruser -s /bin/bash -m silveruser \
  && mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${MAVEN_SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn \
  && unzip /tmp/maven-deps.zip -d /home/silveruser/ \
  && chown -R silveruser:users /home/silveruser/.m2 \
  && curl -fsSL -o /tmp/swftools-bin-0.9.2.zip https://www.silverpeas.org/files/swftools-bin-0.9.2.zip \
  && echo 'd40bd091c84bde2872f2733a3c767b3a686c8e8477a3af3a96ef347cf05c5e43 *swftools-bin-0.9.2.zip' | sha256sum - \
  && unzip /tmp/swftools-bin-0.9.2.zip -d / \
  && curl -fsSL -o /tmp/pdf2json-bin-0.68.zip https://www.silverpeas.org/files/pdf2json-bin-0.68.zip \
  && echo 'eec849cdd75224f9d44c0999ed1fbe8764a773d8ab0cf7fff4bf922ab81c9f84 *pdf2json-bin-0.68.zip' | sha256sum - \
  && unzip /tmp/pdf2json-bin-0.68.zip -d / \
  && curl -fsSL -o /tmp/wildfly-${WILDFLY_VERSION}.Final.FOR-TESTS.zip https://www.silverpeas.org/files/wildfly-${WILDFLY_VERSION}.Final.FOR-TESTS.zip \
  && mkdir /opt/wildfly-for-tests \
  && unzip /tmp/wildfly-${WILDFLY_VERSION}.Final.FOR-TESTS.zip -d /opt/wildfly-for-tests/ \
  && chown -R silveruser:users /opt/wildfly-for-tests/ \
  && sed -i 's/\/home\/miguel\/tmp/\/opt\/wildfly-for-tests/g' /opt/wildfly-for-tests/wildfly-15.0.1.Final/standalone/configuration/standalone-full.xml \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
  && echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen \
  && update-locale LANG=${DEFAULT_LOCALE} LANGUAGE=${DEFAULT_LOCALE} LC_ALL=${DEFAULT_LOCALE}

COPY src/inputrc /home/silveruser/.inputrc
COPY src/settings.xml /home/silveruser/.m2/

ENV LANG ${DEFAULT_LOCALE}
ENV LANGUAGE ${DEFAULT_LOCALE}
ENV LC_ALL ${DEFAULT_LOCALE}
ENV MAVEN_HOME /usr/share/maven
ENV JAVA_HOME /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64

# By default, the build will be done in the default user's home directory
USER silveruser
WORKDIR /home/silveruser

# The GPG and SSL keys to use for respectively signing and then deploying the built artifact to
# our Nexus server have to to be provided by an outside directory; therefore the below definition
# of volumes.
# WARNING: You have to link also two files in order to be able to deploy the build results and to
# push commits:
# - /home/silveruser/.m2/settings.xml and /home/silveruser/.m2/settings-security.xml files with your
# own in order to sign and to deploy the artifact with Maven. In these files the GPG key, the SSL
# passphrase as well as the remote servers must be defined.
# - /home/silveruser/.m2/.gitconfig file with your own in order to be able to push any commits.
VOLUME ["/home/silveruser/.ssh", "/home/silveruser/.gnupg"]
