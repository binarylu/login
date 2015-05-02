#!/bin/bash

base_dir="$(cd "$(dirname "$0")"; pwd)"
iplist="${base_dir}/ip.list"
pwd_file="${base_dir}/pwd.conf"
exp_script="${base_dir}/login.exp"

[ -f "/usr/bin/sw_vers" ] && os="mac" || os="linux"

usage() {
    [ -n "$1" ] && echo "error: $1"
    echo "Usage: $0 [-u user] [-p password] [-P port] [[0-9]|ip|domain]"
}

if [ "$os" = "mac" ]; then
    args=`getopt hu:p:P: "$@"`
else
    args=`getopt -o hu:p:P: -n 'wrong parameter' -- "$@"`
fi

if [ $? -ne 0 ] ; then
    #echo "Fatal error happens when handle parameters!" >&2
    exit 1
fi
eval set -- "$args"

_user=""
_pw=""
_port=""
addr=""

while true; do
    case "$1" in
        -h) usage;exit 0; shift;;
        -u) _user=$2;      shift 2;;
        -p) _pw=$2;        shift 2;;
        -P) _port=$2;      shift 2;;
        --) shift; break;;
         *) echo "Internal error!"; exit 1;;
    esac
done
addr=$1

if [ -z "${addr}" ]; then
    width=`cat ${iplist} | awk -F'|' 'BEGIN {width=0} {if (length($NF)>width) width=length($NF);} END {print width}'`
    [ $width -lt 50 ] && width=50

    perl -e 'print "+", "-"x3, "+", "-"x20, "+", "-"x'$width', "+\n"'
    printf "|%-3s|%-20s|%-"$width"s|\n" "No." "address" "comment"
    perl -e 'print "+", "-"x3, "+", "-"x20, "+", "-"x'$width', "+\n"'
    cat $iplist | grep -v "^#" | awk -v w="$width" -F"|" '{printf("|%-3s|%-20s|%-"w"s|\n", NR, $1, $2)}'
    perl -e 'print "+", "-"x3, "+", "-"x20, "+", "-"x'$width', "+\n"'

    read -n1 -p "Login: " num
    echo ""
    [ -z "`echo $num | grep '^[0-9]*$'`" ] && exit 2
    addr=`cat $iplist | grep -v "^#" | sed -n "${num}p" | cut -d"|" -f1`
    [ -z "$addr" ] && exit 3
else
    if [ -n "`echo $1 | grep '^[0-9]*$'`" ]; then
        addr=`cat $iplist | grep -v "^#" | sed -n "${1}p" | cut -d"|" -f1`
        [ -z "$addr" ] && exit 3
    fi
fi

if [ -z "${addr}" ]; then
    usage "address not found!"
    exit 3
fi

port=`[ -n "${_port}" ] && echo ${_port} || grep ${addr} $pwd_file | tail -1 | awk -F"|" '{print $2}'`
user=`[ -n "${_user}" ] && echo ${_user} || grep ${addr} $pwd_file | tail -1 | awk -F"|" '{print $3}'`
pw=`[ -n "${_pw}" ]     && echo ${_pw}   || grep ${addr} $pwd_file | tail -1 | awk -F"|" '{print $4}'`

# set a default user and password
[ -z "${port}" ] && port=""
[ -z "${use}r" ] && user=""
[ -z "${pw}" ] && pw=""

${exp_script} "$addr" "$port" "$user" "$pw"
ret=$?

if [ $ret -eq 0 ];then
    # if this is a mac os
    if [ $os = "mac" ]; then
        [ -n "${_port}" -o -n "${_user}" -o -n "${_pw}" ] && sed -i "" '/'$addr'/d' "${pwd_file}" && echo "${addr}|${port}|${user}|${pw}" >> "${pwd_file}"
    else
        echo -ne "\\033]0;$addr \\007"
        [ -n "${_port}" -o -n "${_user}" -o -n "${_pw}" ] && sed -i '/'$addr'/d' "${pwd_file}" && echo "${addr}|${port}|${user}|${pw}" >> "${pwd_file}"
    fi
else
    [ $os = "mac" ] && echo "login failed!" || echo -e "\n\e[31;1mlogin failed!\e[0m"
fi
exit $ret
