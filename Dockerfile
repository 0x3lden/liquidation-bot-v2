# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12.5
FROM python:${PYTHON_VERSION} as base

RUN apt-get update && apt-get install -y nodejs npm

WORKDIR /forge-repo

# Manually clone submodules
RUN mkdir -p lib/forge-std && \
    git clone https://github.com/foundry-rs/forge-std.git lib/forge-std

# Copy the project files
COPY . /forge-repo

RUN curl -L https://foundry.paradigm.xyz | bash

RUN bash -c "source ~/.bashrc && foundryup"

# Initialize git repository
RUN git init
RUN git config --global user.email "you@example.com"
RUN git config --global user.name "Your Name"
RUN git add --all
RUN git commit -m "Initial commit"

# Run Forge commands
RUN bash -c "source ~/.bashrc && forge install --no-commit"
RUN bash -c "source ~/.bashrc && forge update"
RUN bash -c "source ~/.bashrc && forge build"

# Create a non-privileged user
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

RUN mkdir -p app/logs app/state

# Install Python dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,source=requirements.txt,target=requirements.txt \
    python -m pip install -r requirements.txt

# Install NPM dependencies
WORKDIR /redstone_script
COPY redstone_script/package.json redstone_script/package-lock.json* ./
RUN npm ci
WORKDIR /forge-repo

# Set correct permissions
RUN chown -R appuser:appuser /forge-repo/ && \
    chmod -R 755 /forge-repo/ && \
    mkdir -p /forge-repo/logs /forge-repo/state && \
    chmod 777 /forge-repo/logs /forge-repo/state

USER appuser

EXPOSE 8080

# CMD ["python", "python/liquidation_bot.py"]
# Run the application
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "application:application"]