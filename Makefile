.PHONY: glide vendor-update docker pilosa pilosactl crossbuild install plugins

GLIDE := $(shell command -v glide 2>/dev/null)
VERSION := $(shell git describe --tags)
IDENTIFIER := $(VERSION)-$(GOOS)-$(GOARCH)
CLONE_URL=github.com/pilosa/pilosa
BUILD_TIME=`date -u +%FT%T%z`
LDFLAGS=-ldflags "-X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME)"

default: test pilosa pilosactl

$(GOPATH)/bin:
	mkdir $(GOPATH)/bin

glide: $(GOPATH)/bin
ifndef GLIDE
	curl https://glide.sh/get | sh
endif

vendor: glide glide.yaml
	glide install

glide.lock: glide glide.yaml
	glide update

vendor-update: glide.lock

test: vendor
	go test $(shell cd $(GOPATH)/src/$(CLONE_URL); go list ./... | grep -v vendor)

pilosa: vendor
	go build $(LDFLAGS) $(FLAGS) $(CLONE_URL)/cmd/pilosa

pilosactl: vendor
	go build $(LDFLAGS) $(FLAGS) $(CLONE_URL)/cmd/pilosactl

crossbuild: vendor
	mkdir -p build/pilosa-$(IDENTIFIER)
	make pilosa FLAGS="-o build/pilosa-$(IDENTIFIER)/pilosa"
	make pilosactl FLAGS="-o build/pilosa-$(IDENTIFIER)/pilosactl"

install: vendor
	go install $(LDFLAGS) $(FLAGS) $(CLONE_URL)/cmd/pilosa
	go install $(LDFLAGS) $(FLAGS) $(CLONE_URL)/cmd/pilosactl

docker: vendor
	docker build -t pilosa:latest .

install: pilosa pilosactl plugins
	@echo "[install] plugins"
	@mkdir -p ~/.pilosa/plugins
	@cp bin/* ~/.pilosa/plugins

pilosa:
	@echo "[install] pilosa"
	@go install ./cmd/pilosa

pilosactl:
	@echo "[install] pilosactl"
	@go install ./cmd/pilosactl

plugins:
	@mkdir -p bin
	@echo "[build] plugin: test"
	@go build -buildmode=plugin -o bin/test.so ./plugins/test
