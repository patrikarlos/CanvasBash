PWD=$(shell pwd)
DESTDIR=$(HOME)
PREFIX=$(DESTDIR)

EXECUTABLES = jq curl
TARGETS= downloadAssignments.sh listAssignments.sh listMyCourses.sh


test:
	@echo "Test"
	K := $(foreach exec,$(EXECUTABLES), \
		$(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))


install: $(TARGETS)
	@echo "Installing to $(PREFIX)/bin"
	install -m 0755 $^ $(PREFIX)/bin

uninstall: 
	@echo "Removing $(PREFIX)/bin"
	rm -f $(addprefix $(PREFIX)/bin/, $(TARGETS))

clean:
	@echo "Cleaning up"
	rm -f *~
