#!/bin/bash

BASE_DIR="$(cd "$(dirname $0)"; pwd)"
RESOURCES_DIR="$BASE_DIR/../root/etc/homeproxy/resources"

TEMP_DIR="$(mktemp -d -p $BASE_DIR)"

to_upper() {
	echo -e "$1" | tr "[a-z]" "[A-Z]"
}

check_list_update() {
	local LIST_TYPE="$1"
	local REPO_NAME="$2"
	local REPO_BRANCH="$3"
	local REPO_FILE="$4"
	local GITHUB_TOKEN="${GITHUB_TOKEN:-}"

	local AUTH_HEADER=""
	[ -n "$GITHUB_TOKEN" ] && AUTH_HEADER="--header=Authorization: Bearer $GITHUB_TOKEN"

	local NEW_VER=""
	NEW_VER="$(curl -sL $AUTH_HEADER "https://api.github.com/repos/$REPO_NAME/releases/latest" 2>/dev/null | jq -r ".tag_name" 2>/dev/null)"
	if [ -z "$NEW_VER" ] || [ "$NEW_VER" = "null" ] || [ "$NEW_VER" = "" ]; then
		echo -e "[$(to_upper "$LIST_TYPE")] Failed to get the latest version, please retry later."
		return 1
	fi

	local OLD_VER="$(cat "$RESOURCES_DIR/$LIST_TYPE.ver" 2>/dev/null || echo "NOT FOUND")"
	if [ "$OLD_VER" = "$NEW_VER" ]; then
		echo -e "[$(to_upper "$LIST_TYPE")] Current version: $NEW_VER."
		echo -e "[$(to_upper "$LIST_TYPE")] You're already at the latest version."
		return 3
	else
		echo -e "[$(to_upper "$LIST_TYPE")] Local version: $OLD_VER, latest version: $NEW_VER."
	fi

	if ! curl -fsSL -o "$TEMP_DIR/$REPO_FILE" "https://cdn.jsdelivr.net/gh/$REPO_NAME@$REPO_BRANCH/$REPO_FILE" || [ ! -s "$TEMP_DIR/$REPO_FILE" ]; then
		rm -f "$TEMP_DIR/$REPO_FILE"
		echo -e "[$(to_upper "$LIST_TYPE")] Update failed."
		return 1
	fi

	mv -f "$TEMP_DIR/$REPO_FILE" "$RESOURCES_DIR/$LIST_TYPE.${REPO_FILE##*.}"
	echo -e "$NEW_VER" > "$RESOURCES_DIR/$LIST_TYPE.ver"
	echo -e "[$(to_upper "$LIST_TYPE")] Successfully updated."

	return 0
}

check_list_update "china_ip4" "laosan-xx/surge-rules" "release" "cncidr.txt" && \
	sed -i "/IP-CIDR6,/d; s/IP-CIDR,//g" "$RESOURCES_DIR/china_ip4.txt"

check_list_update "china_ip6" "laosan-xx/surge-rules" "release" "cncidr.txt" && \
	sed -i "/IP-CIDR,/d; s/IP-CIDR6,//g" "$RESOURCES_DIR/china_ip6.txt"

check_list_update "gfw_list" "laosan-xx/surge-rules" "release" "gfw.txt" && \
	sed -i "s/^\.//g" "$RESOURCES_DIR/gfw_list.txt"

check_list_update "china_list" "laosan-xx/surge-rules" "release" "direct.txt" && \
	sed -i "s/^\.//g" "$RESOURCES_DIR/china_list.txt"


rm -rf "$TEMP_DIR"
