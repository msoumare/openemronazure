## Moved from data-gen/Dockerfile
FROM mcr.microsoft.com/devcontainers/java:21-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip git unzip wget && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip3 install --no-cache-dir -r requirements.txt

ARG SYNTHEA_VERSION=master
RUN git clone --depth 1 --branch ${SYNTHEA_VERSION} https://github.com/synthetichealth/synthea.git /opt/synthea \
    && cd /opt/synthea \
    && ./gradlew --no-daemon clean build installDist

COPY run.sh /app/run.sh
COPY etl.py /app/etl.py
RUN chmod +x /app/run.sh

ENV JAVA_OPTS="-Xms512m -Xmx1g"

ENTRYPOINT ["/app/run.sh"]