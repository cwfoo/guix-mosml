# guix-mosml
This is a [Guix](https://guix.gnu.org) channel for installing
[Moscow ML](https://mosml.org) using the Guix package manager. This channel
provides two Guix packages: `mosml` and `mosml-full`.

Part of Moscow ML is licensed under the
[CAML Light 0.6 license](https://github.com/kfl/mosml/blob/ver-2.10.1/copyrght/copyrght.cl),
which is considered non-free. Therefore, Moscow ML cannot be distributed by the
official Guix channel.


## Usage
### Channel
To use this repository as a Guix channel:

1. Add `guix-mosml` to `~/.config/guix/channels.scm`:
    ```scheme
    (cons (channel
            (name 'guix-mosml)
            (url "https://github.com/cwfoo/guix-mosml"))
          %default-channels)
    ```
2. Run `guix pull`.
3. Install mosml: `guix install mosml` or `guix install mosml-full`.

### Load path
Alternatively, you could clone the guix-mosml repository, and install mosml by
specifying a load path:

1. Clone the repository: `git clone https://github.com/cwfoo/guix-mosml`.
2. `cd guix-mosml`.
3. Install mosml: `guix install -L . mosml` or `guix install -L . mosml-full`.


## Differences between mosml and mosml-full
`mosml-full` includes additional dynamically linked libraries:
* `Gdbm` and `Polygdbm` — GNU dbm library.
* `Gdimage` — Library for creating PNG images.
* `Mysql` — Interface to the MySQL database server.
* `Postgres` — Interface to the PostgreSQL database server.
* `Regex` — Regular expression library.

However, lots of patches were needed to compile `mosml-full` (especially for the
`Mysql` library) and lots of compiler warnings are still produced. Use at your
own risk. If you do not need the libraries listed above, install `mosml` instead
of `mosml-full`.


## License
All files in this repository are licensed under the GNU General Public License,
version 3 or (at your option) any later version.


## Contributing
Bug reports, suggestions, and patches should be submitted on GitHub:
https://github.com/cwfoo/guix-mosml
