FROM harbor.tuxgrid.com/docker.io/golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY src/ ./src/
RUN go build -o server ./src/

FROM harbor.tuxgrid.com/docker.io/alpine:3.20
RUN addgroup -S app && adduser -S app -G app
USER app
COPY --from=builder /app/server /server
EXPOSE 8080
CMD ["/server"]
