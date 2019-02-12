spiff-packages
===

This is a collection of xbps package templates. I haven't yet set up automated
builds for these, and they change..  almost never (there's an exception to
this). So, this is currently a manual thing.

Requirements
---

To use spiff-packages, you need to have [mergerfs(1)][], [git(1)][], and
[fex(1)][] installed. These can all be installed using XBPS.

[mergerfs(1)]: https://man.voidlinux.org/man1/mergerfs
[git(1)]: https://man.voidlinux.org/man1/git
[fex(1)]: https://man.voidlinux.org/man1/fex

Steps to Build
---

1. Prepare the void-packages repository:

    ```
    $ ./ws init
    ```

2. Install the bootstrap packages (you can also do this normally from the
   void-packages directory):

    ```
    $ ./ws binary-bootstrap
    ```

3. From then, you can pass any command to `ws` to create package bindings and
   run xbps-src with a given command. For example, to run `xbps-src pkg`:

    ```
    $ ./ws pkg retrap
    ```

Running Other Programs
---

To run an arbitrary program in the void-packages workspace with bindings in
place, you can use `ws run`:

    ```
    $ ./ws run xgensum srcpkgs/template/retrap
    ```

Building All Packages
---

To run a command against all known packages, you can use the text `{pkg}` in
a command line in place of a package name and ws will run the command for all
packages it identifies.

   ```
   $ ./ws pkg {pkg}
   ```

How This Works
---

Most of the detail of this repository is contained in the `ws` script. First,
what `./ws init` does is clones both void-packages and xtools, or if they're
already cloned, updates them to HEAD.

Then, for any subsequent command, such as `./ws pkg {pkg}`, it creates
a temporary mergerfs mount that merges void-packages and the root directory
(under which srcpkgs is contained). By doing this, it keeps personal package
templates separate from the main void-packages commit history and allows me to
maintain these independently of void-packages (since it moves quite quickly).

The mergerfs mount only exists for the duration of the ws command being
executed. It's possible that the mount will survive in the event of a crash or
unexpected signal (no attempt is made to handle all signals), however, in which
case you can use `fusermount -u .work` (`.work` is the default name of the
mount).
