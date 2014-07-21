DIST := .el6

.PHONY: all rpms srpms srpm_repo

all: rpms srpm_repo


############################################################################
# RPM build rules
############################################################################

# Build a source RPM from a Spec file and a tarball.   We define %dist
# to ensure that the names of the source RPMs, which are built outside the
# mock chroot, match the names of the binary RPMs, which are built inside
# the chroot.	Without this we might generate foo-1.0.fc20.src.rpm
# (Fedora host) and foo-1.0.el6.x86_64.rpm (CentOS chroot).
%.src.rpm:
	@unbuffer rpmbuild --define "_topdir ." --define "%dist $(DIST)" -bs $< | ts "$(LOGPREFIX) [RPMBUILD]"

# Phony target to create repository metadata for the SRPMs.   This makes
# it possible to add the SRPMS directory to yum.conf and use yumdownloader
# to install source RPMs.
srpm_repo: srpms
	@unbuffer flock --timeout 30 ./SRPMS createrepo --update ./SRPMS | ts "$(LOGPREFIX) [CREATEREPO]"

# Build one or more binary RPMs from a source RPM.   A typical source RPM
# might produce a base binary RPM, a -devel binary RPM containing library
# and header files and a -debuginfo binary RPM containing debug symbols.
# The repository metadata is updated after building a binary package so that
# a subsequent mock build for a package which depend on this one is able
# to find and install it.
%.rpm:
	@unbuffer mock --configdir=mock -r xenserver --resultdir=$(dir $@) --uniqueext=$(notdir $@) --rebuild $< | ts "$(LOGPREFIX) [MOCK]"
	@flock --timeout 30 ./RPMS createrepo --update ./RPMS | ts "$(LOGPREFIX) [CREATEREPO]"


############################################################################
# Deb build rules
############################################################################

# Build a Debian source package from a Spec file and a tarball.
# makedeb.py loads the Spec file, generates an equivalent Debian source
# directory structure, then runs 'dpkg-source' to create the .dsc file.
# The conversion is basic, but works fairly well for straightforward Spec
# files.
%.dsc: 
	@unbuffer scripts/deb/makedeb.py $< | ts "$(LOGPREFIX) [MAKEDEB]"
	@unbuffer flock --timeout 30 ./SRPMS scripts/deb/updaterepo sources SRPMS | ts "$(LOGPREFIX) [UPDATEREPO]"

# Build one or more binary Debian packages from from a source package.
# As with the RPM build, a typical source package might produce several
# binary packages.  The repository metadata is updated after building a
# binary package so that a subsequent build for a package which depends
# on this one is able to find and install it.
%.deb:
	@mkdir -p logs
	@touch RPMS/Packages	
	@sudo unbuffer cowbuilder --build \
		--configfile pbuilder/pbuilderrc \
		--buildresult RPMS $< | ts "$(LOGPREFIX) [COWBUILDER]"
	@unbuffer flock --timeout 30 ./RPMS scripts/deb/updaterepo packages RPMS | ts "$(LOGPREFIX) [UPDATEREPO]"


############################################################################
# Dependency build rules
############################################################################

# Generate dependency rules linking spec files to tarballs, source
# packages and binary packages.   specdep.py generates rules suitable
# for RPM or Debian builds depending on the host distribution.
deps: SPECS/*.spec specdep.py scripts/lib/mappkgname.py
	@echo Updating dependencies...
	@./specdep.py -d $(DIST) --ignore-from ignore SPECS/*.spec > $@

-include deps

