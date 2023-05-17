PWD=$(shell pwd)
DESTDIR=$(HOME)
PREFIX=$(DESTDIR)

EXECUTABLES = jq curl md5
TARGETS= gradeStatus.sh downloadAssignments.sh listAssignments.sh listMyCourses.sh uploadFeedback.sh remainToReview.sh removeMyCommentsOnAssignment.sh


test:
	@echo "Test"
	K := $(foreach exec,$(EXECUTABLES), \
		$(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH")))


install: $(TARGETS)
	@echo "Installing to $(PREFIX)/bin"
	install -m 0755 $^ $(PREFIX)/bin

update: $(TARGETS)
	@echo "Updating $(PREFIX)/bin"
	install -m 0755 $^ $(PREFIX)/bin


uninstall: 
	@echo "Removing $(PREFIX)/bin"
	rm -f $(addprefix $(PREFIX)/bin/, $(TARGETS))

clean:
	@echo "Cleaning up"
	rm -f *~
