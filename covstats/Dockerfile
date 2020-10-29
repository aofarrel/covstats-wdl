FROM golang:1.15

RUN go get -u github.com/brentp/goleft/...
RUN go install github.com/brentp/goleft/cmd/goleft

WORKDIR /go/src/goleft
COPY . .

CMD ["goleft"]
