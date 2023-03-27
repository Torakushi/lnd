FROM golang:1.19.7-alpine as builder

# Force Go to use the cgo based DNS resolver. This is required to ensure DNS
# queries required to connect to linked containers succeed.
ENV GODEBUG netdns=cgo

# Pass a tag, branch or a commit using build-arg.  This allows a docker
# image to be built from a specified Git state.  The default image
# will use the Git tip of master by default.
ARG checkout="lol"

# Install dependencies and build the binaries.
RUN apk add --no-cache --update alpine-sdk \
    git \
    make \
    gcc \
&&  git clone https://github.com/Torakushi/lnd /go/src/github.com/lightningnetwork/lnd \
&&  cd /go/src/github.com/lightningnetwork/lnd \
&&  git checkout $checkout \
&&  make \
&&  make install tags="signrpc walletrpc chainrpc invoicesrpc routerrpc"

# Start a new, final image.
FROM alpine as final

# Define a root volume for data persistence.
VOLUME /root/.lnd

# Add bash and ca-certs, for quality of life and SSL-related reasons.
RUN apk --no-cache add \
    bash \
    su-exec \
    ca-certificates

# Copy the binaries from the builder image.
COPY --from=builder /go/bin/lncli /bin/
COPY --from=builder /go/bin/lnd /bin/

COPY docker-entrypoint.sh /entrypoint.sh

RUN chmod a+x /entrypoint.sh
# Expose lnd ports (p2p, rpc).
VOLUME ["/home/lnd/.lnd"]

EXPOSE 9735 8080 10000

# Specify the start command and entrypoint as the lnd daemon.
ENTRYPOINT ["/entrypoint.sh"]

CMD ["lnd"]