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

    # frag: knife sshgen
    # frag end

Now `frag` that file:

    frag ~/.ssh/config

and the fragment delimited by the `frag:`...`frag end` lines will be filled in
with the output from [knife sshgen][knife-sshgen]. The delimiter lines remain,
so you can re-`frag` anytime to bring it up to date.

Or maybe you want your `/etc/hosts` to set a list of local subdomains from a
database:

    127.0.0.1        localhost
    255.255.255.255  broadcasthost
    ::1              localhost
    fe80::1%lo0      localhost

    # frag: mysql myapp -Bre 'select subdomain from sites | sed -e 's/.*/127.0.0.1 &.myapp.local/'
    # frag end

The command is passed through the [standard shell][standard-shell], so pipelines
work fine.

[chef]: http://www.opscode.com/chef
[knife-sshgen]: https://github.com/harvesthq/knife-plugins/blob/master/.chef/plugins/knife/sshgen.rb
[standard-shell]: http://www.ruby-doc.org/core-1.9.3/Process.html#method-c-exec

## Too simple?

Make life complicated with these customizable options.

### Comment Syntax

By default, frag assumes the fragment delimiters start with a '#' (followed by
optional whitespace). Change that with`-l` or `--leader`:

    frag -l '--' magic.hs

If your comments need trailing characters too, there's `-t` or `--trailer`:

    frag -l '/*' -t '*/' magic.cc

### Custom Delimiters

If you want to choose your own delimiters.

    frag -b 'FRAGGED BY' -e 'FRAGGED' file.txt

Now your fragments can look like:

    # FRAGGED BY ...
    ...
    # FRAGGED

### Backups

Back up the original file by providing a suffix:

    frag -s '.backup' file.txt

Or dump all your backups into a directory with a prefix:

    frag -p ~/.frag-backups/ file.txt

### Embedded options

If you actually do need those options above, it's a pain to type them on the
command line every time. Instead, you can embed the frag options in the file
itself:

    <!-- $frag-config: -b BEGIN -e END -->
    <!-- BEGIN echo hi -->
    <!-- END -->

The leader and trailer will be taken from that of the $frag-config line itself,
so you don't need to specify them with the `-l` and `-t` options like earlier.

You can also use this if you need different comment syntaxes for different parts
of the file. For example, if you're embedding CSS in HTML:

    <!-- $frag-config: -->
    <!-- frag: echo hi -->
    <!-- frag end -->

    ...

    /* $frag-config: */
    /* frag: echo hi */
    /* frag end */

    ...

## Note on Patches/Pull Requests

 * Bug reports: http://github.com/oggy/frag/issues
 * Source: http://github.com/oggy/frag
 * Patches: Fork on Github, send pull request.
   * Ensure patch includes tests.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) George Ogata. See LICENSE for details.
