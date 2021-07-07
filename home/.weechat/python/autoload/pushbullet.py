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
    'access_token': ('', 'Access Token obtained at https://www