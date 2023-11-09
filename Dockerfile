FROM alpine:3.18
RUN apk add --no-cache procps bash curl 
ENTRYPOINT ["/bin/sh"]
