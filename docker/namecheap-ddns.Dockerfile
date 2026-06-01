FROM alpine:3.20

RUN apk add --no-cache ca-certificates curl tzdata

COPY scripts/namecheap-ddns.sh /usr/local/bin/namecheap-ddns
COPY scripts/namecheap-ddns-entrypoint.sh /usr/local/bin/namecheap-ddns-entrypoint

RUN chmod 0755 /usr/local/bin/namecheap-ddns /usr/local/bin/namecheap-ddns-entrypoint

ENTRYPOINT ["/usr/local/bin/namecheap-ddns-entrypoint"]
CMD ["crond", "-f", "-l", "8"]
