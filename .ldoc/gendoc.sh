#!/usr/bin/env bash

d_ldoc="$(dirname $(readlink -f $0))"
d_root="$(dirname ${d_ldoc})"
f_config="${d_ldoc}/config.ld"
d_export="${d_export:-${d_root}/docs/reference}"

cd "${d_root}"

# clean old files
rm -rf "${d_export}"

rm -f "${d_ldoc}/README.md"

if test ! -x "${d_ldoc}/parse_readme.py"; then
	chmod +x "${d_ldoc}/parse_readme.py"
fi

"${d_ldoc}/parse_readme.py"

vinfo="v$(grep "version = " "${d_root}/mod.conf" | sed -e 's/version = //')"

# use temp config so sound previews can be linked to master branch
f_config_tmp="${d_ldoc}/config_tmp.ld"
cp "${f_config}" "${f_config_tmp}"
sed -i -e 's/local version = .*$/local version = master/' "${f_config_tmp}"

# create new files
ldoc --UNSAFE_NO_SANDBOX -c "${f_config_tmp}" -d "${d_export}/${vinfo}" "${d_root}"

# show version info
for html in $(find "${d_export}/${vinfo}" -type f -name "*.html"); do
	sed -i -e "s|^<h1>Sounds</h1>$|<h1>Sounds <span style=\"font-size:12pt;\">(${vinfo})</span></h1>|" "${html}"
done

# copy screenshot
screenshot="${d_root}/screenshot.png"
if test -f "${screenshot}"; then
	cp "${d_root}/screenshot.png" "${d_export}/${vinfo}"
fi

# cleanup
rm -f "${d_ldoc}/README.md" "${f_config_tmp}"
