#!/bin/bash
#
# Copyright (C) 2017 Canonical Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This script creates boot, recovery, and userdata images for UC16 for
# the Link SBC board. Opposed to brando-build-script.sh, it is thought
# for creating images for local testing instead of production ones. It
# requires already built kernel and gadget snaps. Note that the script
# does not need to run in an armhf arch.

set -ex

kernel_snap="$1"
gadget_snap="$2"

# Source auxiliary functions
. ./generate-core-image.sh

core_name=""
kernel_name=""
generate_core_image "$kernel_snap" "$gadget_snap" "" false "" core_name kernel_name

if [ -z "$kernel_snap" ]; then
    echo "Will use generated kernel snap"
    kernel_snap=$kernel_name
fi

sudo ./generate-core-boot-image.sh "$kernel_snap" "$core_name" "$kernel_name"