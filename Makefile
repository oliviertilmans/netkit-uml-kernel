#     Copyright 2007-2008 Massimo Rimondini - Computer Networks Research Group,
#     Roma Tre University.
#
#     This file is part of Netkit.
#
#     Netkit is free software: you can redistribute it and/or modify it under
#     the terms of the GNU General Public License as published by the Free
#     Software Foundation, either version 3 of the License, or (at your option)
#     any later version.
#
#     Netkit is distributed in the hope that it will be useful, but WITHOUT ANY
#     WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#     FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#     details.
#
#     You should have received a copy of the GNU General Public License along
#     with Netkit.  If not, see <http://www.gnu.org/licenses/>.


# The following variables should contain relative paths
BUILD_DIR=build
MODULES_DIR=modules
PATCHES_DIR=patches
INCLUDES_DIR=include

include Makefile.config

export $(SUBARCH)
export $(KERNEL_RELEASE)
export $(KERNEL_SUFFIX)
export $(KERNEL_URL)

##############################################################################
## Settings below these lines should in general never be touched.
##############################################################################

# The CDPATH environment variable can cause problems
override CDPATH=
NK_KERNEL_RELEASE=$(shell awk '/kernel version/ {print $$NF}' netkit-kernel-version)
KERNEL_PACKAGE=linux-$(KERNEL_RELEASE)$(KERNEL_SUFFIX)
KERNEL_DIR=$(patsubst %$(KERNEL_SUFFIX),%,$(KERNEL_PACKAGE))

default: help

.PHONY: help
help:
	@echo
	@echo -e "\e[1mAvailable targets are:\e[0m"
	@echo
	@echo -e "  \e[1mkernel\e[0m     Build a Netkit kernel. The current directory must contain"
	@echo "             the source $(KERNEL_SUFFIX) package for vanilla kernel $(KERNEL_RELEASE)."
	@echo "             If no such package is available, the makefile will attempt"
	@echo "             to automatically download one. Other files required for the"
	@echo "             build will be automatically downloaded too."
	@echo
	@echo -e "  \e[1mpackage\e[0m    Create a distributable tarball of the Netkit kernel."
	@echo
	@echo -e "  \e[1mclean\e[0m      Remove files from previous builds."
	@echo
	@echo -e "\e[1mAvailable variables are:\e[0m"
	@echo
	@echo -e "   \e[1mSUBARCH\e[0m   Specifies the target architecture on which the kernel is"
	@echo "             supposed to run. Possible values are: i386, ia64, ppc, and"
	@echo "             x86_64 (default: $(SUBARCH))."
	@echo
	@echo -e "   \e[1mKERNEL_RELEASE\e[0m Specifies the version of the kernel to be compiled"
	@echo "             (default: $(KERNEL_RELEASE))."
	@echo

.PHONY: kernel
kernel: netkit-kernel

.SILENT: netkit-kernel
netkit-kernel: $(BUILD_DIR)/$(KERNEL_DIR)/.config
	echo -e "\n\e[1m\e[32m========= Compiling the kernel... ========\e[0m"
	mkdir -p $(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel
	+$(MAKE) -C $(BUILD_DIR)/$(KERNEL_DIR)/ all ARCH=um SUBARCH=$(SUBARCH) INSTALL_MOD_PATH="../../$(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/$(MODULES_DIR)"
	+$(MAKE) -C $(BUILD_DIR)/$(KERNEL_DIR)/ modules ARCH=um SUBARCH=$(SUBARCH) INSTALL_MOD_PATH="../../$(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/$(MODULES_DIR)"
	+$(MAKE) -C $(BUILD_DIR)/$(KERNEL_DIR)/ modules_install ARCH=um SUBARCH=$(SUBARCH) INSTALL_MOD_PATH="../../$(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/$(MODULES_DIR)"
	rm -f $(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/$(MODULES_DIR)/lib/modules/*/{source,build}
	cp $(BUILD_DIR)/$(KERNEL_DIR)/linux $(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/netkit-kernel-$(SUBARCH)-$(KERNEL_RELEASE)-$(NK_KERNEL_RELEASE)
	ln -fs netkit-kernel-$(SUBARCH)-$(KERNEL_RELEASE)-$(NK_KERNEL_RELEASE) $(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/netkit-kernel

.SILENT: $(BUILD_DIR)/$(KERNEL_DIR)/.patched
$(BUILD_DIR)/$(KERNEL_DIR)/.patched: $(BUILD_DIR)/$(KERNEL_DIR)/.unpacked
	echo -e "\n\e[1m\e[32m==========  Applying patches... ==========\e[0m"
	cd $(CURDIR)/$(BUILD_DIR)/$(KERNEL_DIR) && find "$(CURDIR)/$(PATCHES_DIR)" -name "*.diff" -type f -print0 | xargs -I '{}' -0 -n 1 /bin/sh -c "patch -p1 < '{}'"
	: > $(BUILD_DIR)/$(KERNEL_DIR)/.patched

.SILENT: $(BUILD_DIR)/$(KERNEL_DIR)/.config
$(BUILD_DIR)/$(KERNEL_DIR)/.config: netkit-kernel-config-$(SUBARCH) $(BUILD_DIR)/$(KERNEL_DIR)/.patched
	echo -e "\n\e[1m\e[32m======= Configuring the kernel... ========\e[0m"
	ln -fs netkit-kernel-config-$(SUBARCH) netkit-kernel-config-$(SUBARCH)-$(KERNEL_RELEASE)-$(NK_KERNEL_RELEASE)
	sed 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-netkit-$(NK_KERNEL_RELEASE)"/' netkit-kernel-config-$(SUBARCH) > $(BUILD_DIR)/$(KERNEL_DIR)/.config
	+$(MAKE) -C $(BUILD_DIR)/$(KERNEL_DIR)/ silentoldconfig ARCH=um SUBARCH=$(SUBARCH)

.SILENT: $(BUILD_DIR)/$(KERNEL_DIR)/.unpacked
$(BUILD_DIR)/$(KERNEL_DIR)/.unpacked: $(KERNEL_PACKAGE)
	echo -e "\n\e[1m\e[32m======== Unpacking the kernel... =========\e[0m"
	mkdir -p $(BUILD_DIR)
	unxz < $(KERNEL_PACKAGE) | tar -C $(BUILD_DIR) -xf -
	: > $(BUILD_DIR)/$(KERNEL_DIR)/.unpacked

$(KERNEL_PACKAGE):
	echo -e "\n\e[1m\e[33m====== Retrieving kernel tarball... ======\e[0m"
	wget $(KERNEL_URL)

.PHONY: package
package: ../netkit-kernel-$(NK_KERNEL_RELEASE).tar.bz2

../netkit-kernel-$(NK_KERNEL_RELEASE).tar.bz2: netkit-kernel
	cp -rf README CHANGES Makefile netkit-kernel-version netkit-kernel-config-i386 netkit-kernel-config-x86_64 patches/ $(BUILD_DIR)/$(PACKAGE_DIR)/netkit/kernel/
	tar -C $(BUILD_DIR)/$(PACKAGE_DIR) -cjf ../netkit-kernel-$(SUBARCH)-$(NK_KERNEL_RELEASE).tar.bz2 netkit/kernel

.PHONY: clean
clean:
	-rm -fr $(BUILD_DIR) netkit-kernel-config-*-K*.*

.PHONY: clean-all
clean-all: clean
	-rm -fr $(KERNEL_PACKAGE) ../netkit-kernel-$(SUBARCH)-$(NK_KERNEL_RELEASE).tar.bz2

