#!/bin/bash
#
# Copyright (C) 2016-2017 Canonical Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

generate_assertions()
{
    read -r -p "Please enter your account id: " user_account_id
    if [ -z "$user_account_id" ] ; then
        echo "ERROR: Invalid account id!"
        exit 1
    fi
    cat << EOF > "$workdir"/model.json
{
"type": "model",
"authority-id": "$user_account_id",
"brand-id": "$user_account_id",
"series": "16",
"model": "$target",
"architecture": "armhf",
"gadget": "$target",
"kernel": "$target-kernel",
"timestamp": "$(date -Iseconds --utc)"
}
EOF

    snap sign < "$workdir"/model.json > "$model_assertion"

    # Password field generated with
    # python3 -c 'import crypt; print(crypt.crypt("test", crypt.mksalt(crypt.METHOD_SHA512)))'
    # (note that '$'s have to be escaped in the HERE document)
    cat << EOF > "$workdir"/test-user-assertion.json
{
"type": "system-user",
"authority-id": "$user_account_id",
"brand-id": "$user_account_id",
"series": ["16"],
"models": ["$target"],
"name": "Default Test User",
"username": "test",
"email": "test@localhost",
"password": "\$6\$OCvKy4w/Ppxp7IvC\$WPzWiIW.4y18h9htjbOuxLZ.sjQ5M2hoSiEu3FpMU0PMdHQuQdBOqvk8p6DMdS/R/nU/rXidClD23CbSkSgp30",
"since": "2016-10-24T07:12:10+00:00",
"until": "2018-10-24T07:12:10+00:00"
}
EOF

    snap sign < "$workdir"/test-user-assertion.json > "$user_assertion"
}

# Generate ready-to-flash image for userdata partition
# $1 OPTIONAL, kernel snap
# $2 OPTIONAL, gadget snap
# $3 OPTIONAL, extra snap
# $4 OPTIONAL, "true" if local build (default), "false" otherwise
# $5 OPTIONAL, OUT, image file name
# $6 OPTIONAL, OUT, core snap name
# $7 OPTIONAL, OUT, kernel snap name
generate_core_image()
{
    workdir=$(mktemp -d)
    kernel=$1
    gadget=$2
    extra=$3
    local_build=true
    if [ "$4" = false ]; then
        local_build=$4
    fi

    if [ -z "$kernel" ]; then
        echo "No kernel snap provided"
    fi

    if [ -z "$gadget" ]; then
        echo "No gadget snap provided"
    fi

    target=dragonboard
    model_assertion="$workdir"/"$target".model
    user_assertion="$workdir"/test-user.assertion
    channel=stable
    image_size=2G
    image_name="$target"-userdata-$(date --utc +%Y%m%d%H%M)
    image_fs_label=writable
    output=$(pwd)

    if [ "$local_build" = "false" ]; then
        # pre-created assertions
        cp ./assertions/"$target".model "$workdir"
        cp ./assertions/test-user.assertion "$workdir"
    else
        generate_assertions
    fi

    mkdir "$workdir"/rootfs
    mkdir "$workdir"/rootfs/boot

    prepare_img_args=(--channel "$channel")
    if [ -n "$kernel" ]; then
        prepare_img_args+=(--extra-snaps "$kernel")
    fi
    if [ -n "$gadget" ]; then
        prepare_img_args+=(--extra-snaps "$gadget")
    fi
    if [ -n "$extra" ]; then
        prepare_img_args+=(--extra-snaps "$extra")
    fi
    prepare_img_args+=("$model_assertion"
                       "$workdir"/rootfs)
    snap prepare-image "${prepare_img_args[@]}"

    sudo chown -R root:root "$workdir"/rootfs

    sudo mkdir "$workdir"/writable
    sudo mkdir "$workdir"/writable/system-data
    sudo cp -ra "$workdir"/rootfs/image/* "$workdir"/writable/system-data/

    (cd "$workdir"/writable ; sudo tar cf "$workdir"/writable.tar -- *)
    sudo tar --numeric-owner --exclude=dev/ -tvvf "$workdir"/writable.tar \
	 --directory "$workdir" | sudo tee "$workdir"/writable.content

    sudo make_ext4fs -u / -U "$workdir"/writable.content -l "$image_size" -s \
	 -L "$image_fs_label" "$workdir"/"$image_name".img "$workdir"/writable

    cp "$workdir"/"$image_name".img "$output"

    # Set output variables now
    if [ -n "$5" ]; then
        eval "$5"="$image_name"
    fi
    if [ -n "$6" ]; then
        eval "$6"="$(find "$workdir"/rootfs/image/var/lib/snapd/seed/snaps/ \
                         -name core_\*.snap -printf "%f\n")"
    fi
    if [ -n "$7" ]; then
        eval "$7"="$(find "$workdir"/rootfs/image/var/lib/snapd/seed/snaps/ \
                         -name $target\*-kernel_\*.snap -printf "%f\n")"
    fi

    sudo rm -rf "$workdir"
}

# Run only if not being sourced
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    set -ex
    generate_core_image "$@"
fi
