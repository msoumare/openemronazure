## Moved from data-gen/Dockerfile
FROM mcr.microsoft.com/devcontainers/java:21-bookworm

# Install required OS packages (python3-venv needed to create isolated env)
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-pip python3-venv git unzip wget ca-certificates \
       fontconfig libfreetype6 graphviz \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
# Create an isolated virtual environment to avoid Debian PEP 668 restriction
RUN python3 -m venv /opt/pyenv \
    && /opt/pyenv/bin/pip install --upgrade pip \
    && /opt/pyenv/bin/pip install --no-cache-dir -r requirements.txt
ENV VIRTUAL_ENV=/opt/pyenv
ENV PATH="/opt/pyenv/bin:$PATH"

ARG SYNTHEA_VERSION=master
# Clone Synthea and build distribution while skipping tests (they require font libs / graphical environment)
RUN git clone --depth 1 --branch ${SYNTHEA_VERSION} https://github.com/synthetichealth/synthea.git /opt/synthea \
    && cd /opt/synthea \
    && ./gradlew --no-daemon clean installDist -x test

COPY run.sh /app/run.sh
COPY etl.py /app/etl.py
COPY synthea.properties /opt/synthea/synthea-local.properties
RUN chmod +x /app/run.sh

ENV JAVA_OPTS="-Xms512m -Xmx1g"
# Force headless mode just in case any AWT usage occurs at runtime
ENV JAVA_TOOL_OPTIONS="-Djava.awt.headless=true"

ENTRYPOINT ["/app/run.sh"]