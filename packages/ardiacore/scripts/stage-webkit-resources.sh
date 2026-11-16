#!/bin/bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
"$here/ubol.sh"
mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ContentRules"
rsync -a --delete "$here/../vendor/ubol-webkit/rules/" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/ContentRules/"
