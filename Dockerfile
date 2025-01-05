FROM alpine:3.21

RUN apk add --no-cache bash curl aws-cli

COPY fs-backup.sh /
COPY backup.sh /

CMD ["/backup.sh"]
