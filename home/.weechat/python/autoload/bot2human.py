# -*- coding:utf-8 -*-
# Bot2Human
#
# Replaces messages from bots to humans
# typically used in channels that are connected with other IMs using bots
#
# For example, if a bot send messages from XMPP is like `[nick] content`,
# weechat would show `bot | [nick] content` which looks bad; this script
# make weecaht display `nick | content` so that the messages looks like
# normal IRC message
#
# Options
#
#   plugins.var.python.bot2human.bot_nicks
#       space seperated nicknames to forwarding bots
#       example: teleboto toxsync tg2arch
#
#   plugins.var.python.nick_content_re.X
#       X is a 0-2 number. This options specifies regex to match nickname
#       and content. Default regexes are r'\[(?P<nick>.+?)\] (?P<text>.*)',
#       r'\((?P<nick>.+?)\) (?P<text>.*)', and r'<(?P<nick>.+?)> (?P<text>.*)'
#
#   plugins.var.python.nick_re_count
#       Number of rules defined
#

# Changelog:
# 0.3.0: Add relayed nicks into nicklist, enabling completion
# 0.2.2: Support ZNC timestamp
# 0.2.1: Color filtering only applies on nicknames
#        More than 3 nick rules can be defined
# 0.2.0: Filter mIRC color and other control seq from message
# 0.1.1: Bug Fixes
# 0.1: Initial Release
#

import weechat as w
import re

SCRIPT_NAME = "bot2human"
SCRIPT_AUTHOR = "Justin Wong & Hexchain & quietlynn"
SCRIPT_DESC = "Replace IRC message nicknames with regex match from chat text"
SCRIPT_VERSION = "0.3.0"
SCRIPT_LICENSE = "GPLv3"

DEFAULTS = {
    'nick_re_count': '4',
    'nick_content_re.0': r'\[(?:\x03[0-9,]+)?(?P<nick>[^:]+?)\x0f?\] (?P<text>.*)',
    'nick_content_re.1': r'(?:\x03[0-9,]+)?\[(?P<nick>[^:]+?)\]\x0f? (?P<text>.*)',
    'nick_content_re.2': r'\((?P<nick>[^:]+?)\) (?P<text>.*)',
    'nick_content_re.3': r'<(?:\x03[0-9,]+)?(?P<nick>[^:]+?)\x0f?> (?P<text>.*)',
    'bot_nicks': "",
    'znc_ts_re': r'\[\d\d:\d\d:\d\d\]\s+',
}

CONFIG = {
    'nick_re_count': -1,
    'nick_content_res': [],
    'bot_nicks': [],
    'znc_ts_re': None,
}


def parse_config():

    for option, default in DEFAULTS.items():
        # print(option, w.config_get_plugin(option))
        if not w.config_is_set_plugin(option):
            w.config_set_plugin(option, default)

    CONFIG['nick_re_count'] = int(w.config_get_plugin('nick_re_count'))
    CONFIG['bot_nicks'] = w.config_get_plugin('bot_nicks').split(' ')
    for i in range(CONFIG['nick_re_count']):
        option = "nick_content_re.{}".format(i)
        CONFIG['nick_content_res'].append(
            re.compile(w.config_get_plugin(option))
        )
    CONFIG['znc_ts_re'] = re.compile(w.config_get_plugin('znc_ts_re'))


def config_cb(data, option, value):
    parse_config()

    return 