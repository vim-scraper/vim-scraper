test:
	bundle exec rake test

.PHONY: image
image:
	docker build -t vim-scraper .

.PHONY: dev
dev:
	docker run -ti -v $(shell pwd):/app vim-scraper bash
