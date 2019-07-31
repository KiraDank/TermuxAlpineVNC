#!/data/data/com.termux/files/usr/bin/env bash

AlpineFS="${PREFIX}/opt/AlpineFS"  # place where will stored Alpine file system
LAUNCH='alpine'  # name of command to start alpine
BIN="${PREFIX}/bin"  # path to bin directory

function test_dir {
	[ -d "$1" ] || mkdir -p "$1"
}


function check_arch {
	ARCH=$(uname -m)
	case ${ARCH} in
		aarch64|armhf|x86|x86_64|ppc64le|s390x|armv7 )
			;;
		* )
			>&2 echo 'unfortunately you have unsupported architecture'
			exit 1
			;;
	esac
}


function check_dependencies {
	printf '* updating apt cache...'
	apt update &>/dev/null

	echo -e '\n'
	echo '* checking dependencies'
	for dependence in proot bsdtar curl; do
		printf "   * ${dependence}..."
		${dependence} --help &>/dev/null && \
		echo 'OK' || {
			printf 'insatlling...'
			apt -y install ${dependence} &>/dev/null || {
				>&2 echo 'unable to install'
				exit 1
			} && echo 'OK'
		}
	done
}


function get_alpine {
	echo '* downloading latest stable Alpine...'
	filename=$(curl -s "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/" | \
			   grep -m 1 -o "alpine-minirootfs-[0-9.]*-${ARCH}.tar.gz" | head -n 1)

	curl --retry 3 -LOf "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/${filename}"

	echo
	curl --retry 3 -Lfs "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/${filename}.sha256" | \
	sha256sum -c - || exit 1
}


function setup_alpine {
	printf '* extracting...'
	proot --link2symlink -0 bsdtar -xpf ${filename} 2>/dev/null && rm -f ${filename} || {
		>&2 echo 'error'
		exit 1
	}

	cat > ${AlpineFS}/etc/resolv.conf <<- EOM
	nameserver 8.8.8.8
	nameserver 8.8.4.4
	EOM

	cat >> ${AlpineFS}/etc/apk/repositories <<- EOM

	http://dl-cdn.alpinelinux.org/alpine/edge/community
	# http://dl-cdn.alpinelinux.org/alpine/edge/testing
	EOM

	cat > ${AlpineFS}/etc/profile <<- EOM
	export CHARSET=UTF-8
	export LANG=C.UTF-8
	export PATH=/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin
	export PAGER=less
	export PS1='[termux@alpine \w] \$ '
	umask 022

	for script in /etc/profile.d/*.sh ; do
	        if [ -r \${script} ] ; then
	                 \${script}
	        fi
	done
	EOM

	cat > ${AlpineFS}/etc/motd <<- EOM
	* After first run recommended update system: \`apk update && apk upgrade\`
	* More info about Alpine package manager:
	    <http://wiki.alpinelinux.org/wiki/Alpine_Linux_package_management/>
	* To setup VNC run 'SetupVNC --help' and choose graphical environment

	The Alpine Wiki contains a large amount of how-to guides and general
	information about administrating Alpine systems.
	See <http://wiki.alpinelinux.org/>

	To remove this text: \`printf ''>/etc/motd\`

	EOM

	cat > ${AlpineFS}/etc/profile.d/motd.sh <<- EOM
	#!/bin/sh
	cat /etc/motd
	EOM
	chmod +x ${AlpineFS}/etc/profile.d/motd.sh

	echo
}


function get_vnc_setup {
	printf '* downloading VNC setup...'
	vnc=${AlpineFS}/usr/local/bin/SetupVNC
	curl --retry 3 -Lfso ${vnc} 'https://raw.githubusercontent.com/Vlone12536/TermuxAlpineVNC/master/SetupVNC.sh'
	chmod +x ${vnc}
	echo
}


function create_launcher {
	launcher=${BIN}/${LAUNCH}

	cat > ${launcher} <<- EOM
	#!/data/data/com.termux/files/usr/bin/env bash
	unset LD_PRELOAD
	AlpineFS="${AlpineFS}"
	shell=/bin/sh

	cmd="proot"
	cmd+=" --link2symlink"
	cmd+=" -0"
	cmd+=" -r \${AlpineFS}"
	cmd+=" -b /mnt"
	cmd+=" -b /dev"
	cmd+=" -b /proc"
	cmd+=" -b /sdcard"
	cmd+=" -b /storage"
	# cmd+=" -b /data/data/com.termux"  # uncomment to mount termux file system
	cmd+=" -w /root"
	cmd+=" /usr/bin/env -i"
	cmd+=" HOME=/root"
	cmd+=" PATH=/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin"
	cmd+=" TERM=\${TERM}"
	cmd+=" LANG=C.UTF-8"
	cmd+=" \${shell} --login"

	if [ -n "\$1" ]; then
	    exec \${cmd} -c \$@
	else
	    exec \${cmd}
	fi
	EOM
	chmod +x ${launcher}
}


function main {
	check_arch
	[ -n "${AlpineFS}" ] || AlpineFS="${PREFIX}/opt/AlpineFS"
	[ -n "${BIN}" ] || BIN="${PREFIX}/bin"
	[ -n "${LAUNCH}" ] || LAUNCH='alpine'

	test_dir ${AlpineFS}
	cd ${AlpineFS}

	check_dependencies
	echo
	get_alpine
	echo
	setup_alpine
	echo
	get_vnc_setup
	create_launcher
	echo
	echo 'done'
	echo "command for start Alpine: '${LAUNCH}'"
	echo "AlpineFS stored in [${AlpineFS}]"
	echo
	echo 'to lounch VNC setup you must execute `SetupVNC` !!! after starting Alpine !!!'
}

case "${1}" in
	uninstall|rm|del* )
		rm -rf ${AlpineFS} ${BIN}/${LAUNCH} &>/dev/null
		echo done
		;;
	info)
		echo "command for start Alpine: '${LAUNCH}'"
		echo "AlpineFS stored in [${AlpineFS}]"
		;;
	'' )
		main
		;;
	* )
		echo "'$0 rm' to unintsall alpine from defasult path"
		echo "'$0 info' to see this path "
		echo "you can also edit it in file: [$(readlink -e $0)]"
		echo 'run without arguments to install'
		;;
esac
