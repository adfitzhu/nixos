#!/bin/sh
set -eu

# Run all install steps in order
dirname=$(dirname "$0")

sh "$dirname/partition.sh"
sh "$dirname/mount.sh"
sh "$dirname/install.sh"
sh "$dirname/setpass.sh"
sh "$dirname/repo.sh"
