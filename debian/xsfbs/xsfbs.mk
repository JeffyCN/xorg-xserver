#!/usr/bin/make -f
# $Id: xsfbs.mk 2284 2006-06-06 18:02:50Z branden $

# Debian rules file for xorg-x11 source package

# Copyright 1996 Stephen Early
# Copyright 1997 Mark Eichin
# Copyright 1998-2005 Branden Robinson
# Copyright 2005 David Nusinow
#
# Licensed under the GNU General Public License, version 2.  See the file
# /usr/share/common-licenses/GPL or <http://www.gnu.org/copyleft/gpl.txt>.

# Originally by Stephen Early <sde1000@debian.org>
# Modified by Mark W. Eichin <eichin@kitten.gen.ma.us>
# Modified by Adam Heath <doogie@debian.org>
# Modified by Branden Robinson <branden@debian.org>
# Modified by Fabio Massimo Di Nitto <fabbione@fabbione.net>
# Modified by David Nusinow <dnusinow@debian.org>
# Acknowledgements to Manoj Srivastava.

# Pass $(DH_OPTIONS) into the environment for debhelper's benefit.
export DH_OPTIONS

# Set up parameters for the upstream build environment.

# Determine (source) package name from Debian changelog.
SOURCE_NAME:=$(shell dpkg-parsechangelog -ldebian/changelog \
                        | grep '^Source:' | awk '{print $$2}')

# Determine package version from Debian changelog.
SOURCE_VERSION:=$(shell dpkg-parsechangelog -ldebian/changelog \
                        | grep '^Version:' | awk '{print $$2}')

# Determine upstream version number.
UPSTREAM_VERSION:=$(shell echo $(SOURCE_VERSION) | sed 's/-.*//')

# Determine the source version without the epoch for make-orig-tar-gz
NO_EPOCH_VER:=$(shell echo $(UPSTREAM_VERSION) | sed 's/^.://')

# Figure out who's building this package.
BUILDER:=$(shell echo $${DEBEMAIL:-$${EMAIL:-$$(echo $$LOGNAME@$$(cat /etc/mailname 2>/dev/null))}})

# Find out if this is an official build; an official build has nothing but
# digits, dots, and/or the strings "woody" or "sarge" in the Debian part of the
# version number.  Anything else indicates an unofficial build.
OFFICIAL_BUILD:=$(shell VERSION=$(SOURCE_VERSION); if ! expr "$$(echo $${VERSION\#\#*-} | sed 's/\(woody\|sarge\)//g')" : ".*[^0-9.].*" >/dev/null 2>&1; then echo yes; fi)

# Set up parameters for the Debian build environment.

# Determine our architecture.
BUILD_ARCH:=$(shell dpkg-architecture -qDEB_BUILD_ARCH)
# Work around some old-time dpkg braindamage.
BUILD_ARCH:=$(subst i486,i386,$(BUILD_ARCH))
# The DEB_HOST_ARCH variable may be set per the Debian cross-compilation policy.
ifdef DEB_HOST_ARCH
 ARCH:=$(DEB_HOST_ARCH)
else
 # dpkg-cross sets the ARCH environment variable; if set, use it.
 ifdef ARCH
  ARCH:=$(ARCH)
 else
  ARCH:=$(BUILD_ARCH)
 endif
endif

# $(STAMP_DIR) houses stamp files for complex targets.
STAMP_DIR:=stampdir

# $(SOURCE_DIR) houses one or more source trees.
SOURCE_DIR:=build-tree

# $(SOURCE_TREE) is the location of the source tree to be compiled.  If there
# is more than one, others are found using this name plus a suffix to indicate
# the purpose of the additional tree (e.g., $(SOURCE_TREE)-custom).  The
# "setup" target is responsible for creating such trees.
#SOURCE_TREE:=$(SOURCE_DIR)/xc
#FIXME We need to define this in our debian/rules file

# $(DEBTREEDIR) is where all install rules are told (via $(DESTDIR)) to place
# their files.
DEBTREEDIR:=$(CURDIR)/debian/tmp

# All "important" targets have four lines:
#   1) A target name that is invoked by a package-building tool or the user.
#      This consists of a dependency on a "$(STAMP_DIR)/"-prefixed counterpart.
#   2) A line delcaring 1) as a phony target (".PHONY:").
#   3) A "$(STAMP_DIR)/"-prefixed target which does the actual work, and may
#   depend on other targets.
#   4) A line declaring 3) as a member of the $(stampdir_targets) variable; the
#   "$(STAMP_DIR)/" prefix is omitted.
#
# This indirection is needed so that the "stamp" files that signify when a rule
# is done can be located in a separate "stampdir".  Recall that make has no way
# to know when a goal has been met for a phony target (like "build" or
# "install").
#
# At the end of each "$(STAMP_DIR)/" target, be sure to run the command ">$@"
# so that the target will not be run again.  Removing the file will make Make
# run the target over.

# All phony targets should be declared as dependencies of .PHONY, even if they
# do not have "($STAMP_DIR)/"-prefixed counterparts.

# Define a harmless default rule to keep things from going nuts by accident.
.PHONY: default
default:

# Set up the $(STAMP_DIR) directory.
.PHONY: stampdir
stampdir_targets+=stampdir
stampdir: $(STAMP_DIR)/stampdir
$(STAMP_DIR)/stampdir:
	mkdir $(STAMP_DIR)
	>$@

# Set up the package build directory as quilt expects to find it.
.PHONY: prepare
stampdir_targets+=prepare
prepare: $(STAMP_DIR)/genscripts $(STAMP_DIR)/prepare $(STAMP_DIR)/patches $(STAMP_DIR)/log
$(STAMP_DIR)/prepare: $(STAMP_DIR)/stampdir
	if [ ! -e $(STAMP_DIR)/patches ]; then \
		mkdir $(STAMP_DIR)/patches; \
		ln -s $(STAMP_DIR)/patches .pc; \
		echo 2 >$(STAMP_DIR)/patches/.version; \
	fi; \
	if [ ! -e $(STAMP_DIR)/log ]; then \
		mkdir $(STAMP_DIR)/log; \
	fi; \
	if [ ! -e patches ]; then \
		ln -s debian/patches patches; \
	fi; \
	>$@

# Apply all patches to the upstream source.
.PHONY: patch
stampdir_targets+=patch
patch: $(STAMP_DIR)/patch
$(STAMP_DIR)/patch: $(STAMP_DIR)/prepare
	if ! [ `which quilt` ]; then \
		echo "Couldn't find quilt. Please install it or add it to the build-depends for this package."; \
		exit 1; \
	fi; \
	if quilt next; then \
	  echo -n "Applying patches..."; \
	  if quilt push -a -v >$(STAMP_DIR)/log/patch 2>&1; then \
	    echo "successful."; \
	  else \
	    echo "failed! (check $(STAMP_DIR)/log/patch for details)"; \
	    exit 1; \
	  fi; \
	else \
	  echo "No patches to apply"; \
	fi; \
	>$@

# Revert all patches to the upstream source.
.PHONY: unpatch
unpatch:
	rm -f $(STAMP_DIR)/patch
	@echo -n "Unapplying patches..."; \
	if [ -e $(STAMP_DIR)/patches/applied-patches ]; then \
	  if quilt pop -a -v >$(STAMP_DIR)/log/unpatch 2>&1; then \
	    echo "successful."; \
	  else \
	    echo "failed! (check $(STAMP_DIR)/log/unpatch for details)"; \
	    exit 1; \
	  fi; \
	else \
	  echo "nothing to do."; \
	fi

# Clean the generated maintainer scripts.
.PHONY: cleanscripts
cleanscripts:
	rm -f $(STAMP_DIR)/genscripts
	rm -f debian/*.config \
	      debian/*.postinst \
	      debian/*.postrm \
	      debian/*.preinst \
	      debian/*.prerm

# Clean the package build tree.
.PHONY: xsfclean
xsfclean: cleanscripts unpatch
	dh_testdir
	rm -f .pc patches
	rm -rf $(STAMP_DIR) $(SOURCE_DIR)
	rm -rf imports
	dh_clean debian/shlibs.local \
	         debian/MANIFEST.$(ARCH) debian/MANIFEST.$(ARCH).new \
	         debian/po/pothead

# Generate the debconf templates POT file header.
debian/po/pothead: debian/po/pothead.in
	sed -e 's/SOURCE_VERSION/$(SOURCE_VERSION)/' \
	  -e 's/DATE/$(shell date "+%F %X%z"/)' <$< >$@

# Update POT and PO files.
.PHONY: updatepo
updatepo: debian/po/pothead
	debian/scripts/debconf-updatepo --pot-header=pothead --verbose

# Use the MANIFEST files to determine whether we're shipping everything we
# expect to ship, and not shipping anything we don't expect to ship.
.PHONY: check-manifest
stampdir_targets+=check-manifest
check-manifest: $(STAMP_DIR)/check-manifest
$(STAMP_DIR)/check-manifest: $(STAMP_DIR)/install
	# Compare manifests.
	(cd debian/tmp && find -type f | LC_ALL=C sort | cut -c3-) \
	  >debian/MANIFEST.$(ARCH).new
	# Construct MANIFEST files from MANIFEST.$(ARCH).in and
	# MANIFEST.$(ARCH).all or MANIFEST.all.
	if expr "$(findstring -DBuildFonts=NO,$(IMAKE_DEFINES))" \
	  : "-DBuildFonts=NO" >/dev/null 2>&1; then \
	  LC_ALL=C sort -u debian/MANIFEST.$(ARCH).in >debian/MANIFEST.$(ARCH); \
	else \
	  if [ -e debian/MANIFEST.$(ARCH).all ]; then \
	    LC_ALL=C sort -u debian/MANIFEST.$(ARCH).in debian/MANIFEST.$(ARCH).all >debian/MANIFEST.$(ARCH); \
	  else \
	    LC_ALL=C sort -u debian/MANIFEST.$(ARCH).in debian/MANIFEST.all >debian/MANIFEST.$(ARCH); \
	  fi; \
	fi
	# Confirm that the installed file list has not changed.
	if [ -e debian/MANIFEST.$(ARCH) ]; then \
	  if ! cmp -s debian/MANIFEST.$(ARCH) debian/MANIFEST.$(ARCH).new; then \
	    diff -U 0 debian/MANIFEST.$(ARCH) debian/MANIFEST.$(ARCH).new || DIFFSTATUS=$$?; \
	    case $${DIFFSTATUS:-0} in \
	      0) ;; \
	      1) if [ -n "$$IGNORE_MANIFEST_CHANGES" ]; then \
	           echo 'MANIFEST check failed; ignoring problem because \$$IGNORE_MANIFEST_CHANGES set' >&2; \
	           echo 'Please ensure that the package maintainer has an up-to-date version of the' >&2; \
	           echo 'MANIFEST.$(ARCH).in file.' >&2; \
	         else \
	           echo 'MANIFEST check failed; please see debian/README' >&2; \
	           exit 1; \
	         fi; \
	         ;; \
	      *) echo "diff reported unexpected exit status $$DIFFSTATUS when performing MANIFEST check" >&2; \
	         exit 1; \
	         ;; \
	    esac; \
	  fi; \
	fi
	>$@

# Because we build (and install) different files depending on whether or not
# any architecture-independent packages are being created, the list of files we
# expect to see will differ; see the discussion of the "build" target above.
.PHONY: check-manifest-arch check-manifest-indep
check-manifest-arch: IMAKE_DEFINES+= -DBuildSpecsDocs=NO -DBuildFonts=NO -DInstallHardcopyDocs=NO
check-manifest-arch: check-manifest
check-manifest-indep: check-manifest

# Remove files from the upstream source tree that we don't need, or which have
# licensing problems.  It must be run before creating the .orig.tar.gz.
#
# Note: This rule is for Debian package maintainers' convenience, and is not
# needed for conventional build scenarios.
.PHONY: prune-upstream-tree
prune-upstream-tree:
	# Ensure we're in the correct directory.
	dh_testdir
	grep -rvh '^#' debian/prune/ | xargs --no-run-if-empty rm -rf

# Change to what should be the correct directory, ensure it is, and if
# so, create the .orig.tar.gz file.  Exclude the debian directory and its
# contents, and any .svn directories and their contents (so that we can safely
# build an .orig.tar.gz from SVN checkout, not just an export).
#
# Note: This rule is for Debian package maintainers' convenience, and is not
# needed for conventional build scenarios.
#
# This rule *IS* the recommended method for creating a new .orig.tar.gz file,
# for the rare situations when one is needed.
.PHONY: make-orig-tar-gz
make-orig-tar-gz: clean prune-upstream-tree
	( cd .. \
	  && if [ $(shell basename $(CURDIR)) != $(SOURCE_NAME)-$(NO_EPOCH_VER) ]; then \
	    echo "Our current working directory has the wrong name. Renaming..." >&2; \
		mv $(CURDIR) $(SOURCE_NAME)-$(NO_EPOCH_VER); \
	  fi; \
	    tar --exclude=debian --exclude=debian/* \
	        --exclude=.svn --exclude=.svn/* \
	        -cf - $(SOURCE_NAME)-$(NO_EPOCH_VER) \
	    | gzip -9 >$(SOURCE_NAME)_$(NO_EPOCH_VER).orig.tar.gz; \
	   )

# Verify that there are no offsets or fuzz in the patches we apply.
#
# Note: This rule is for Debian package maintainers' convenience, and is not
# needed for conventional build scenarios.
.PHONY: patch-audit
patch-audit: prepare unpatch
	@echo -n "Auditing patches..."; \
	>$(STAMP_DIR)/log/patch; \
	FUZZY=; \
	while [ -n "$$(quilt next)" ]; do \
	  RESULT=$$(quilt push -v | tee -a $(STAMP_DIR)/log/patch | grep ^Hunk | sed 's/^Hunk.*\(succeeded\|FAILED\).*/\1/');\
	  case "$$RESULT" in \
	    succeeded) \
	      echo "fuzzy patch: $$(quilt top)" \
	        | tee -a $(STAMP_DIR)/log/$$(quilt top); \
	      FUZZY=yes; \
	      ;; \
	    FAILED) \
	      echo "broken patch: $$(quilt next)" \
	        | tee -a $(STAMP_DIR)/log/$$(quilt next); \
	      exit 1; \
	      ;; \
	  esac; \
	done; \
	if [ -n "$$FUZZY" ]; then \
	  echo "there were fuzzy patches; please fix."; \
	  exit 1; \
	else \
	  echo "done."; \
	fi

# Generate the maintainer scripts.
.PHONY: genscripts
stampdir_targets+=genscripts
genscripts: $(STAMP_DIR)/genscripts
$(STAMP_DIR)/genscripts: $(STAMP_DIR)/stampdir
	for FILE in debian/*.config.in \
	            debian/*.postinst.in \
	            debian/*.postrm.in \
	            debian/*.preinst.in \
	            debian/*.prerm.in; do \
	  if [ -e "$$FILE" ]; then \
	    MAINTSCRIPT=$$(echo $$FILE | sed 's/.in$$//'); \
	    sed -n '1,/^#INCLUDE_SHELL_LIB#$$/p' <$$FILE \
	      | sed -e '/^#INCLUDE_SHELL_LIB#$$/d' >$$MAINTSCRIPT.tmp; \
	    cat debian/xsfbs/xsfbs.sh >>$$MAINTSCRIPT.tmp; \
	    sed -n '/^#INCLUDE_SHELL_LIB#$$/,$$p' <$$FILE \
	      | sed -e '/^#INCLUDE_SHELL_LIB#$$/d' >>$$MAINTSCRIPT.tmp; \
	    sed -e 's/@SOURCE_VERSION@/$(SOURCE_VERSION)/' \
	        -e 's/@OFFICIAL_BUILD@/$(OFFICIAL_BUILD)/' \
	        -e 's/@DEFAULT_DCRESOLUTIONS@/$(DEFAULT_DCRESOLUTIONS)/' \
	      <$$MAINTSCRIPT.tmp >$$MAINTSCRIPT; \
	    rm $$MAINTSCRIPT.tmp; \
	  fi; \
	done
	# Validate syntax of generated shell scripts.
	#sh debian/scripts/validate-posix-sh debian/*.config \
	#                                    debian/*.postinst \
	#                                    debian/*.postrm \
	#                                    debian/*.preinst \
	#                                    debian/*.prerm
	>$@

# Generate the shlibs.local file.
debian/shlibs.local:
	cat debian/*.shlibs >$@

include debian/xsfbs/xsfbs-autoreconf.mk

# vim:set noet ai sts=8 sw=8 tw=0:
