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

Pipelines work - woo!

Or maybe you're authoring this README and want to show all the options `frag`
takes:

<!-- GEN: echo; ruby -Ilib bin/frag --help | sed -e 's/^/    /'; echo  -->

    USAGE: bin/frag [options] file ...
        -b, --begin DELIMITER
        -e, --end DELIMITER
        -l, --leader STRING
        -t, --trailer STRING
        -p, --backup-prefix PREFIX
        -s, --backup-suffix SUFFIX

<!-- ENDGEN -->

(Check the source... ;-)

[chef]: http://www.opscode.com/chef
[knife-sshgen]: https://github.com/harvesthq/knife-plugins/blob/master/.chef/plugins/knife/sshgen.rb

## Too simple?

Make things complicated with these customizable options.

### Comment Syntax

By default, frag assumes the beginning and ending lines for each fragment start
with a '#' (followed by optional whitespace). Change that with`-l` or
`--leader`:

    frag -l '--' magic.hs

If your comments need trailing characters too, there's `-t` or `--trailer`:

    frag -l '/*' -t '*/' magic.cc

### Custom Delimiters

If you want to choose your own delimiters.

    frag -b 'FRAGGED BY' -e 'FRAGGED' file.txt

Now your regions can look like:

    # FRAGGED BY ...
    ...
    # FRAGGED

### Backups

Back up the original file by providing a suffix:

    frag -s '.backup' file.txt

Or dump all your backups into a directory with a prefix:

    frag -p ~/.frag-backups file.txt

## Note on Patches/Pull Requests

 * Bug reports: http://github.com/oggy/frag/issues
 * Source: http://github.com/oggy/frag
 * Patches: Fork on Github, send pull request.
   * Ensure patch includes tests.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) George Ogata. See LICENSE for details.
