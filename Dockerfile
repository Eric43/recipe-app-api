FROM ghcr.io/astral-sh/uv:python3.11-alpine3.23
LABEL maintainer="eric.olle@gmail.com"

ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache postgresql-client jpeg-dev && \
    apk add --update --no-cache --virtual .tmp-build-deps \
        build-base postgresql-dev musl-dev zlib zlib-dev

WORKDIR /recipe_api_app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Omit development dependencies
ENV UV_NO_DEV=0

# Ensure installed tools can be executed out of the box
ENV UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_CACHE_DIR=/app/.cache/uv

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=cache,target=/root/.ruff_cache \
    uv sync --frozen --no-install-project

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
# Note instead of copy to /app copy to /<name of folder> i.e. /recipe_app
COPY . /recipe_api_app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen

RUN apk del .tmp-build-deps && \
    adduser \
        --disabled-password \
        --no-create-home \
        django-user
        # Creating local directories for static and media #
RUN mkdir -p /vol/web/media && \
    mkdir -p /vol/web/static && \
    chown -R django-user:django-user /vol && \
    chmod 755 /vol
# removed the group add part here
# Install the project into `/app`
# Place executables in the environment at the front of the path
ENV PATH="/recipe_api_app/app/.venv/bin:$PATH"
WORKDIR /recipe_api_app/app
# Reset the entrypoint, don't invoke `uv`
ENTRYPOINT []

# Use the non-root user to run our application
USER django-user

# Run the FastAPI application by default
# Uses `uv run` to sync dependencies on startup, respecting UV_NO_DEV
# Uses `fastapi dev` to enable hot-reloading when the `watch` sync occurs
# Uses `--host 0.0.0.0` to allow access from outside the container
# Note in production, you should use `fastapi run` instead
