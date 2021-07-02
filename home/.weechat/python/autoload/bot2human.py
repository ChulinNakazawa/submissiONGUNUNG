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
SCRIPT_AUTHOR =