# -*- coding:utf-8 -*-
# pastebin

import collections, re, subprocess
import weechat as w

SCRIPT_NAME = 'pastebin'
SCRIPT_AUTHOR = 'MaskRay'
SCRIPT_DESC = '/paste /tmp/a.{jpg,txt} to send its pastebin/imagebin URL to the current buffer'
SCRIPT_VERSION = '0.0.0'
SCRIPT_LICENSE = 'GPLv3'
TIMEOUT = 10 * 1000

process_output = ''
buffers = collections.deque()

def pastebin_process_cb(data, command, rc, out, err):
    #w.prnt('', '{} {} {} {} {}'.format(data, command, rc, out, err))
    global process_output
    process_output += out
    if int(rc) >= 0:
        buffer = buffers.popleft()
        if re.match(r'^https?://', process_output):
            w.command(buffer, '/say '+process_output)
        else:
            w.prnt(buffer, str(process_output))
        process_output = ''
    return w.WEEC