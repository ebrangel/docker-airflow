# VERSION 1.10.5
# AUTHOR: Matthieu "Puckel_" Roisil
# DESCRIPTION: Basic Airflow container
# BUILD: docker build --rm -t puckel/docker-airflow .
# SOURCE: https://github.com/puckel/docker-airflow

FROM python:3.7-slim-stretch
LABEL maintainer="Puckel_"

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.5
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow \
    && addgroup --gid 999 vboxsf \
    && usermod -aG vboxsf airflow


# Install Oracle Instant Client
ENV ORACLE_HOME=/usr/lib/oracle/19.3/client64
ENV PATH=$PATH:$ORACLE_HOME/bin
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib

ADD oracle-instantclient19.3-basic-19.3.0.0.0-1.x86_64.rpm /tmp/
ADD oracle-instantclient19.3-sqlplus-19.3.0.0.0-1.x86_64.rpm /tmp/
ADD oracle-instantclient19.3-devel-19.3.0.0.0-1.x86_64.rpm /tmp/

# Setup locale, Oracle instant client and Python
RUN apt-get update \
    && apt-get -y install alien libaio1 \
    && alien -i /tmp/oracle-instantclient19.3-basic-19.3.0.0.0-1.x86_64.rpm \
    && alien -i /tmp/oracle-instantclient19.3-sqlplus-19.3.0.0.0-1.x86_64.rpm \
    && alien -i /tmp/oracle-instantclient19.3-devel-19.3.0.0.0-1.x86_64.rpm \
    && ln -snf /usr/lib/oracle/19.3/client64 /opt/oracle \
    && mkdir -p /opt/oracle/network \
    && ln -snf /etc/oracle /opt/oracle/network/admin \
    && pip install cx_oracle \
    && apt-get clean && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install MS SQL
ENV ACCEPT_EULA=Y

RUN apt-get update && apt-get install -y \
    gnupg2 \
    curl apt-transport-https debconf-utils && \
    echo "deb http://deb.debian.org/debian jessie main" >> /etc/apt/sources.list && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    apt-get upgrade -y libc6 && \
    apt-get install -y \
        msodbcsql17 \
        mssql-tools \
        unixodbc-dev \
        libssl1.0.0  && \
    apt-get install -y --reinstall --upgrade \
        g++ \
        gcc && \
    /bin/bash -c "source ~/.bashrc" && \
    pip install --upgrade \
        six \
        pyodbc \
        psycopg2-binary && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

RUN pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[crypto,celery,postgres,oracle,mssql,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'redis==3.2' \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY script/entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg

RUN chown -R airflow: ${AIRFLOW_USER_HOME}

EXPOSE 8080 5555 8793

USER airflow
ENV PATH="$PATH:/opt/mssql-tools/bin:/usr/local/airflow/.local/bin"
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"] # set default arg for entrypoint
