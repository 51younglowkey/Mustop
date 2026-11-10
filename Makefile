.PHONY: build icon release clean

build:
	zsh Scripts/build.sh

icon:
	zsh Scripts/make-icns.sh

release:
	zsh Scripts/release.sh

clean:
	rm -rf build dist
