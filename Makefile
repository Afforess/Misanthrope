VERSION := 0.0.1
NAME := Misanthrope

all:
	rm -rf build/
	mkdir build/
	mkdir build/$(NAME)_$(VERSION)
	cp -R LICENSE README.md data.lua info.json control.lua libs build/$(NAME)_$(VERSION)
	cd build && zip -r $(NAME)_$(VERSION).zip $(NAME)_$(VERSION)
clean:
	rm -rf build/
