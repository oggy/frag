## Frag

Generate fragments of files from the output of shell commands.

## Why? How?

Sometimes you want to generate just part of a file programatically. For example,
you might want to generate your `~/.ssh/config` from a list of hosts managed by
[Chef][chef]:

    Host a
      Hostname 123.123.123.1
      User me

    Host b
      Hostname 123.123.123.2
      User me

    # GEN: knife sshgen
    # ENDGEN

Now `frag` that file:

    frag ~/.ssh/config

and the region delimited by the `GEN`..`ENDGEN` lines will be filled in with the
output from [knife sshgen][knife-sshgen]. The delimiter lines remain, so you can
re-`frag` anytime to bring it up to date.

Or maybe you want your `/etc/hosts` to set a list of local subdomains from a
database:

    127.0.0.1        localhost
    255.255.255.255  broadcasthost
    ::1              localhost
    fe80::1%lo0      localhost

    # GEN: mysql myapp -Bre 'select subdomain from sites | sed -e 's/.*/127.0.0.1 &.myapp.local/'
    # ENDGEN

Yes, pipelines work.

[chef]: http://www.opscode.com/chef
[knife-sshgen]: https://github.com/harvesthq/knife-plugins/blob/master/.chef/plugins/knife/sshgen.rb

## Note on Patches/Pull Requests

 * Bug reports: http://github.com/oggy/frag/issues
 * Source: http://github.com/oggy/frag
 * Patches: Fork on Github, send pull request.
   * Ensure patch includes tests.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) George Ogata. See LICENSE for details.
