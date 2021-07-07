# -*- coding:utf-8 -*-
# pushbullet
#
# Adapted from pushover.pl by stfn <stfnmd@gmail.com>

import weechat as w

import json, time, urllib2

SCRIPT_NAME = 'pushbullet'
SCRIPT_AUTHOR = 'MaskRay'
SCRIPT_DESC = 'Send notifications to pushbullet.com on `notify_private,notify_highlight`'
SCRIPT_VERSION = '0.0.0'
SCRIPT_LICENSE = 'GPL3'

DEFAULTS = {
    'access_token': ('', 'Access Token obtained at https://www.pushbullet.com/#settings/account'),
    'blacklist': ('', 'Comma separated list of buffers (`buffer_match_list`) to blacklist for notifications'),
    'rate_limit': ('0', 'Rate limit in seconds (0 = unlimited), will send a maximum of 1 notification per time limit'),
    'show_highlight': ('on', 'Notify on `notify_highlight`'),
}
CONFIG = {}
last = {}


def parse_config():
    for option, (default, desc) in DEFAULTS.items():
        if not w.config_is_set_plugin(option):
            w.config_set_plugin(option, default)
        w.config_set_desc_plugin(option, '{} (default: {!r})'.format(desc, default))
    CONFIG['rate_limit'] = int(w.config_get_plugin('rate_limit'))
    for i in ('access_token', '