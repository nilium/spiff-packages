spiff-packages
===

This is a collection of xbps package templates. I haven't yet set up automated
builds for these, and they change..  almost never (there's an exception to
this). So, this is currently a manual thing.

Steps to Build
---

1. Run `create-overlay` to create the `build` overlay.
2. From the `build` directory, use xbps-src as usual to build packages.

I'll eventually get this to work a little more cleanly, but for now this works.
