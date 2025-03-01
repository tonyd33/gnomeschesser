FROM ghcr.io/gleam-lang/gleam:v1.8.1-node-slim

# Install Deno
COPY --from=denoland/deno:bin-2.2.2 /deno /usr/local/bin/deno
RUN chown -R 777 /usr/local/bin/deno

WORKDIR /build

COPY . /build

# Compile the project
RUN cd /build \
  && gleam build --target javascript \
  && mv build/dev/javascript /app \
  && rm -r /build

# Run the server
WORKDIR /app
RUN echo "main()" >> /app/javascript_template/javascript_template.mjs
CMD ["deno", "--allow-net", "/app/javascript_template/javascript_template.mjs"]
