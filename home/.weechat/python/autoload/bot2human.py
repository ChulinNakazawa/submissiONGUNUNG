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
#   plugins.var.python