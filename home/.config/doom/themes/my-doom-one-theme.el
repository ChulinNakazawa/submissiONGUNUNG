;;; my-doom-one-theme.el --- inspired by Atom One Dark -*- no-byte-compile: t; -*-
(require 'doom-themes)

;;
(defgroup my-doom-one-theme nil
  "Options for doom-themes"
  :group 'doom-themes)

(defcustom my-doom-one-brighter-modeline nil
  "If non-nil, more vivid colors will be used to style the mode-line."
  :group 'my-doom-one-theme
  :type 'boolean)

(defcustom my-doom-one-brighter-comments t
  "If non-nil, comments will be highlighted in more vivid colors."
  :group 'my-doom-one-theme
  :type 'boolean)

(defcustom my-doom-one-comment-bg my-doom-one-brighter-comments
  "If non-nil, comments will have a subtle, darker background. Enhancing their
legibility."
  :group 'my-doom-one-theme
  :type 'boolean)

(defcustom my-doom-one-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds a 4px padding to the mode-line. Can be an integer to
determine the exact padding."
  :group 'my-doom-one-theme
  :type '(choice integer boolean))

;;
(def-doom-theme my-doom-one
  "A dark theme inspired by Atom One Dark"

  