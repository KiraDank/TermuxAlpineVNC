#!/data/data/com.termux/files/usr/bin/env bash

AlpineFS="${PREFIX}/opt/AlpineFS"  # place where will stored Alpine file system
LAUNCH='alpine'  # name of command to start alpine


function test_dir {
    [ -d "${1}" ] || mkdir -p "${1}"
}


function check_arch {
    arch=$(uname -m)
    case ${arch} in
        aarch64|armhf|x86|x86_64|ppc64le|s390x|armv7 )
            echo ${arch}
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
                echo 'unable to install'
                exit 1
            } && echo 'OK'
        }
    done
}


function get_alpine {
    echo '* downloading latest stable Alpine...'
    filename=$(curl -s "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/" | \
    grep -m 1 -o "alpine-minirootfs-[0-9.]*-${ARCH}.tar.gz" | \
    head -n 1)

    curl --retry 3 -LOf "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/${filename}"

    echo
    curl --retry 3 -Lfs "http://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ARCH}/${filename}.sha256" | \
    sha256sum -c - || exit 1


}


function setup_alpine {
printf '* extracting...'
proot --link2symlink -0 bsdtar -xpf ${filename} 2>/dev/null

cat << EOF > ${AlpineFS}/etc/profile
export CHARSET=UTF-8
export LANG=C.UTF-8
export PATH=/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin
export PAGER=less
export PS1='[termux@alpine \w] \$ '
umask 022

for script in /etc/profile.d/*.sh ; do
        if [ -r ${script} ] ; then
                . ${script}
        fi
done
EOF

cat << EOF > ${AlpineFS}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
echo

cat << EOF >> ${AlpineFS}/etc/apk/repositories

http://dl-cdn.alpinelinux.org/alpine/edge/community
# http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF
}


function get_vnc_setup {
    printf '* downloading VNC setup...'
    vnc=${AlpineFS}/usr/local/bin/SetupVNC
    curl --retry 3 -Lfo ${vnc} 'https://raw.githubusercontent.com/Vlone12536/TermuxAlpineVNC/master/SetupVNC.sh'
    chmod +x ${vnc}
    echo
}


function create_launcher {
[ -n "${LAUNCH}" ] || LAUNCH='alpine'
launcher=${PREFIX}/bin/${LAUNCH}

cat << EOF > ${launcher}
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

if [ -n "\${1}" ]; then
    exec \${cmd} -c \${@}
else
    exec \${cmd}
fi
EOF
chmod +x ${launcher}
}


function main {
    ARCH=$(check_arch)
    [ -n "${AlpineFS}" ] || AlpineFS="${PREFIX}/opt/AlpineFS"

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
        rm -rf ${AlpineFS} ${PREFIX}/bin/${LAUNCH} &>/dev/null
        echo done
        ;;
    '' )
        main
        ;;
    * )
        echo "'${0} rm' to unintsall alpine from defasult path"
        echo 'run without arguments to install'
        ;;
esac
