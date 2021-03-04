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

  ;; name        default   256       16
  ((bg         '("#000000" nil       nil            ))
   (bg-alt     '("#21242b" nil       nil            ))
   (base0      '("#1B2229" "black"   "black"        ))
   (base1      '("#1c1f24" "#1e1e1e" "brightblack"  ))
   (base2      '("#202328" "#2e2e2e" "brightblack"  ))
   (base3      '("#23272e" "#262626" "brightblack"  ))
   (base4      '("#3f444a" "#3f3f3f" "brightblack"  ))
   (base5      '("#5B6268" "#525252" "brightblack"  ))
   (base6      '("#73797e" "#6b6b6b" "brightblack"  ))
   (base7      '("#9ca0a4" "#979797" "brightblack"  ))
   (base8      '("#DFDFDF" "#dfdfdf" "white"        ))
   (fg         '("#bbc2cf" "#bfbfbf" "brightwhite"  ))
   (fg-alt     '("#5B6268" "#2d2d2d" "white"        )