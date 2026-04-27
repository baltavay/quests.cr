build:
	shards build --release

clean:
	rm -f bin/quests

.PHONY: build clean
