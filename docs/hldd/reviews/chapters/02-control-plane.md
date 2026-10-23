---
digest: 6ca9a834408a12e1c9a666920927dc154ea406239616809492defdb1e6b1bbfe
disposition: updated
kind: chapter
mapping_digest: null
path: marshall/priv/hldd/02-control-plane.md
reviewed_chapters: {}
state: present
version: 2
---

Guest-credential authentication (inference, Galileo, Peach) now locks hosts FOR KEY SHARE so it never queues behind exchanges; host enable, drain, retire and those credentials issue/rotate/revoke take a FOR UPDATE fence that excludes in-flight readers (02-control-plane host lock paragraph).
