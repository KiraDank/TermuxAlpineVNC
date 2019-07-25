#!/bin/sh

case ${1} in
    xfce* )
        DE='xfce4'
        CMD='/usr/bin/startxfce4'
        ;;
    ''|openbox* )
        DE='openbox'
        CMD='/usr/bin/openbox'
        ;;
    i3* )
        DE='i3wm'
        CMD='/usr/bin/i3'
        ;;
    *)
        echo 'chose from:'
        echo '  * openbox [default]'
        echo '  * xfce'
        echo '  * i3'
        echo
        echo "${0} {openbox|xfce|i3}"
        exit 0
        ;;
esac


printf '* updating apk cache...'
apk update &>/dev/null || {
    echo
    >&2 echo 'unable to update cache'
    exit 1
} && echo


echo
echo 'installing packages...'
apk add xvfb x11vnc ${DE} xfce4-terminal faenza-icon-theme supervisor


cat << EOF >/etc/supervisord.conf
[supervisord]
nodaemon=true

[program:xvfb]
command=/usr/bin/Xvfb :1 -screen 0 720x1024x24
autorestart=true
priority=100
user=root

[program:x11vnc]
command=/usr/bin/x11vnc -permitfiletransfer -tightfilexfer -display :1 -noxrecord -noxdamage -noxfixes -wait 5 -shared -noshm -nopw -xkb
autorestart=true
priority=200
user=root

[program:GraphicalEnvironment]
environment=DISPLAY=":1"
autorestart=true
command=${CMD}
priority=300
user=root
EOF

cat << EOF >/usr/local/bin/startx
#!/bin/sh
case \${1} in
    '' )
        /usr/bin/supervisord -c /etc/supervisord.conf
        ;;
    bg )
        (/usr/bin/supervisord -c /etc/supervisord.conf &>/dev/null &) &
        ;;
    kill )
        killall supervisord &>/dev/null || echo 'not running'
        ;;
    * )
        echo '\${0} {bg|kill}'
        echo '  * bg - run in background'
        echo '  * kill - stop VNC'
        echo 'run without arguments to see log'
        ;;
esac
EOF
chmod +x /usr/local/bin/startx


echo
echo 'done'
echo
echo '`startx` to start VNC'
echo 'you cen edit config in `/etc/supervisord.conf`'
