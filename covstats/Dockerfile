FROM golang:1.15

# install goleft
RUN go get -u github.com/brentp/goleft/...
RUN go install github.com/brentp/goleft/cmd/goleft
#WORKDIR /go/src/goleft
#COPY . .

# install bzip2 (required for samtools installation)
#RUN wget ftp://sources.redhat.com/pub/bzip2/bzip2-1.0.8.tar.gz
#RUN gunzip bzip2-1.0.8.tar.gz
#RUN tar -xzv bzip2-1.0.8.tar.gz
RUN apt-get update
RUN apt-get install bzip2
#RUN make -f Makefile-libbz2_so
#RUN make clean
#RUN make
#RUN make install

# install samtools
WORKDIR /usr/bin
RUN wget https://github.com/samtools/samtools/releases/download/1.9/samtools-1.9.tar.bz2
RUN tar -vxjf samtools-1.9.tar.bz2
RUN cd samtools-1.9
RUN ls && sleep 500
RUN make

WORKDIR /go/src/goleft

CMD ["ls"]