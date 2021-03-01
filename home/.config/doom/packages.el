;; -*- no-byte-compile: t; -*-
;;; private/my/packages.el
(disable-packages! cmake-mode company-irony company-irony-c-headers flycheck-irony irony irony-eldoc ivy-rtags rtags)

(package! avy)
(package! atomic-chrome)
(package! eglot)
(package! lispyville)
;; (package! lsp-mode :ignore t)
;; (package! lsp-treemacs :ignore t)
;; (package! lsp-ui :ignore t)
(package! spinner)                      ; required by lsp-mode

(package! annotate)
(package! eshell-autojump)
(package! evil-collection)
(package! evil-nerd-commenter)
(package! frog-jump-buffer)
(package! git-link)
(package! link-hint)
(package! h