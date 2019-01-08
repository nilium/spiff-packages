spiff-packages
===

This is a collection of xbps package templates. I haven't yet set up automated
builds for these, and they change..  almost never (there's an exception to
this). So, this is currently a manual thing.

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
