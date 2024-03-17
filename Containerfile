FROM docker.io/hugomods/hugo AS builder

WORKDIR /build
COPY . /build

RUN hugo

FROM docker.io/nginx
COPY --from=builder /build/public /usr/share/nginx/html
