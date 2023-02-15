FROM julia:1.7-buster

ENV RELOG_TIME_LIMIT_SEC=3600

# Install Node.js & zip
RUN apt-get update -yq && \
    apt-get -yq install curl gnupg ca-certificates && \
    curl -L https://deb.nodesource.com/setup_18.x | bash && \
    apt-get update -yq && \
    apt-get install -yq nodejs zip

# Install Julia dependencies
ADD Project.toml /app/
ADD src/RELOG.jl /app/src/
RUN julia --project=/app -e 'using Pkg; Pkg.update()'

# Install JS dependencies
ADD relog-web/package*.json /app/relog-web/
RUN cd /app/relog-web && npm install

# Copy source code
ADD . /app
RUN julia --project=/app -e 'using Pkg; Pkg.precompile()'

# Build JS app
RUN cd /app/relog-web && npm run build

WORKDIR /app
CMD julia --project=/app -e 'import RELOG; RELOG.web("0.0.0.0")'
