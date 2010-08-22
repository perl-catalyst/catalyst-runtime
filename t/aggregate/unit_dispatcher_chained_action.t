# Test case for Chained Actions

use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Catalyst::Test 'ChainedActionsApp';
use Test::More tests => 7;

content_like('/', qr/Application Home Page/, 'Application home');
content_like('/15/GoldFinger', qr/List project GoldFinger pages/, 'GoldFinger Project Index');
content_like('/15/GoldFinger/4/007', qr/This is 007 page of GoldFinger project/, '007 page in GoldFinger Project');
content_like('/account', qr/New account o login/, 'no account');
content_like('/account/ferz', qr/This is account ferz/, 'account');
content_like('/account/123', qr/This is account 123/, 'account');
action_notfound('/c');

1;

__END__

(12:32:59) ferz: t0m: I've fixed but /*/* still gets precedence on /account/*
(12:33:46) ferz: /*/* is defined in Root.pm controller while /account/* is defined in Account.pm controller
(12:34:35) shadowpaste: "ferz" at 217.168.150.38 pasted "[debug] Loaded Chained actions" (29 lines) at http://paste.scsys.co.uk/48847

[debug] Loaded Chained actions:
.-------------------------------------+--------------------------------------.
| Path Spec                           | Private                              |
+-------------------------------------+--------------------------------------+
| /account/*                          | /setup (0)                           |
|                                     | -> /account/account_base (0)         |
|                                     | => /account/account                  |
| /account                            | /setup (0)                           |
|                                     | => /account/no_account               |
| /...                                | /setup (0)                           |
|                                     | => /default                          |
| /                                   | /setup (0)                           |
|                                     | => /home                             |
| /*/*/*/*                            | /setup (0)                           |
|                                     | -> /home_base (2)                    |
|                                     | => /hpage                            |
| /*/*                                | /setup (0)                           |
|                                     | -> /home_base (2)                    |
|                                     | => /hpages                           |
.----------------------------------------------------------------------------.

(12:36:24) ferz: how can I change the precedence between them?
(12:37:26) mst: um. /account/* should definitely beat /*/*
(12:37:38) mst: ah
(12:37:43) mst: hang on
(12:37:57) ferz: I'm here, I don't escape
(12:37:59) mst: use CaptureArgs(1) in account_base and make account Args(0)

(12:40:03) ferz: mst: so CaputeArgs(0) is deprecated when endpoints need at least one argument
(12:40:29) mst: wtf?
(12:40:52) mst: ferz: current code please.
(12:45:18) ferz: mst: I'd understood from man and book that CapturedArgs(0) was valid for midpoints and Args( 1,2,...) for endpoints. You have just suggested me a fix to make CaptureArgs(1) instead for midpoint and Args(0) for endpoint, probably I've misunderstood it from man.
(12:45:43) mst: ferz: please just show me the current code you have
(12:45:53) mst: it's going to be easier to use that as an example to explain this
(12:47:20) shadowpaste: "ferz" at 217.168.150.38 pasted "These are action defined in Ro" (94 lines) at http://paste.scsys.co.uk/48848
(12:48:19) mst: ferz: ok, so.
(12:48:36) mst: sub account : Chained('/account/account_base') PathPart('') CaptureArgs(1) {
(12:48:37) mst: then
(12:48:41) ferz: mst: I'm fixing as you suggested
(12:48:48) mst: sub account_view :Chained('account') :PathPart('') :Args(0)
(12:50:22) mst: ferz: the point is that CaptureArgs is part of the Chained feature set
(12:50:30) mst: ferz: but Args is part of the general catalyst dispacther features
(12:50:43) mst: ferz: so the Chained precendence logic only works for CaptureArgs
(12:53:38) ferz: mst: I understand, but there is something still wrong even if I use CaptureArgs(1) on account_base, I will show you the new code and chained action table.
(12:59:04) shadowpaste: "ferz" at 217.168.150.38 pasted "/account/123 still execute hpage() instead of account()" (65 lines) at http://paste.scsys.co.uk/48850
(13:00:32) ferz: http://paste.scsys.co.uk/48851 from catalyst console
(13:01:06) mst: debug output on startup?
(13:02:36) ferz: ok
(13:03:57) shadowpaste: "ferz" at 217.168.150.38 pasted "[debug] Debug messages enabled" (73 lines) at http://paste.scsys.co.uk/48852
(13:04:40) ferz: mst: I've seen that I can upgrade to latest version, I'll report debug after catalyst update
(13:12:35) mst: ferz: that should bloody well work.
(13:16:49) ferz: it doesn't   
(13:17:17) mst: I just don't get it.
(13:17:37) mst: since I wrote the bit of the code that should make this work, and I can still see it in the source.
(13:18:36) mst: ferz: can you delete all the other chains and see if that fixes it?
(13:18:44) mst: since if it doesn't what's left should make a catalyst test :)
(13:56:30) ferz: ok mst
(14:07:36) ferz: I've simplified it more but it still fails, I prepare the catalyst test
(14:08:46) mst: ok, can I see the simplified version please?
(14:08:52) mst: I want to double check I've not missed anything
(14:09:19) ferz: ok, I've place everything in the Root.pm controller
(14:12:28) mst: ferz: show :)
(14:12:28) shadowpaste: "ferz" at 217.168.150.38 pasted "Everything in Root.pm controller" (97 lines) at http://paste.scsys.co.uk/48856
(14:13:21) mst: ferz: kill the hpage action
(14:13:24) mst: and the default
(14:13:29) mst: and 'home'
(14:13:33) ferz: ok
(14:15:33) ferz: done, it fails yet
(14:15:49) mst: ok. show me code and startup debug please.
(14:15:54) ferz: ok
(14:17:38) shadowpaste: "ferz" at 217.168.150.38 pasted "> perl script/test_chained_ser" (136 lines) at http://paste.scsys.co.uk/48857
(14:18:29) mst: and /account/1 still fires hpages?
(14:18:50) ferz: yes, it is
(14:19:44) mst: ok. comment out the hpages stuff and let's check that /account/* works without /*/* there
(14:20:50) ferz: without hpage() it works fine
(14:22:06) mst: could you try one more thing
(14:22:18) mst: split account_base into two actions
(14:22:32) mst: so the non-'' PathPart and the non-zero CaptureArgs are separate
(14:23:59) ferz: Here there is output of previous tests http://paste.scsys.co.uk/48858  now I try splitting it as you suggest.
(14:26:45) ferz: mst I don't understand you last suggestion: split account_base in two actions, two midpoints?
(14:27:16) ferz: s/you/your/
(14:27:21) mst: yes.
(14:29:33) ferz: sub first_account_base : Chained('setup) PathPart('account') CaptureArgs(0) and the other sub second_account_base Chained('first_account_base') Path('') Args(1) ?
(14:29:49) mst: CaptureArgs(1)
(14:29:57) ferz: yes, ok
(14:30:00) mst: and then chain account off second_account_base
(14:30:05) ferz: sure
(14:33:06) shadowpaste: "ferz" at 217.168.150.38 pasted "> perl script/test_chained_ser" (65 lines) at http://paste.scsys.co.uk/48859
(14:33:35) mst: ok, thought so.
(14:34:34) ferz: mst: I fear about my mistake on something about home_base or hpage()
(14:36:04) mst: ferz: well if that's the case we're both wrong.
(14:36:10) ferz: s/hpage/hpages/
(14:36:49) ferz: since they are both on same controller I try still to invert their order in source
(14:37:29) ferz: but the result is the same
(14:38:42) mst: yeah
