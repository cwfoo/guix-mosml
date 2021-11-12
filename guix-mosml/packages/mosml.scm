;;; guix-mosml — Moscow ML packages for GNU Guix.
;;; Copyright (C) 2021 Foo Chuan Wei
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(define-module (guix-mosml packages mosml)
  #:use-module (guix build-system gnu)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages dbm)
  #:use-module (gnu packages gd)
  #:use-module (gnu packages image)
  #:use-module (gnu packages multiprecision)
  #:use-module (gnu packages perl))

(define license (@@ (guix licenses) license))

;;; Moscow ML, without additional libraries.
;;; mosml is considered non-free software because of the CAML Light 0.6 license.
(define-public mosml
  (package
    (name "mosml")
    (version "2.10.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
              (url "https://github.com/kfl/mosml")
              (commit (string-append "ver-" version))))
       (file-name (git-file-name name version))
       (sha256
         (base32 "1jiyvdm8bxbfz6l6m1svwi7md5gzp0y5mx4p1dldhd1vyddgvb8q"))))
    (build-system gnu-build-system)
    (arguments
      `(#:make-flags
        (list (string-append "PREFIX=" %output))
        #:phases
        (modify-phases %standard-phases
          (delete 'configure)
          (add-before 'build 'chdir-to-src
            (lambda _
              (chdir "src")
              #t))
          (add-before 'build 'fix-makefile-sh-path
            (lambda _
              (substitute* "Makefile.inc"
                (("^SHELL[[:space:]]*=[[:space:]]*/bin/sh")
                 (string-append "SHELL=" (which "sh"))))
              #t))
          (add-after 'install 'install-man-pages
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (man1 (string-append out "/share/man/man1")))
                (chdir (assoc-ref %build-inputs "source"))
                (mkdir-p man1)
                (copy-recursively "man" man1))
              #t)))
        #:tests? #f))
    (native-inputs `(("perl" ,perl)))
    (inputs `(("gmp" ,gmp)))
    (home-page "https://mosml.org")
    (synopsis "Moscow ML is a light-weight implementation of Standard ML (SML)")
    (description
      "Moscow ML is a light-weight implementation of Standard ML (SML), a strict
functional language widely used in teaching and research.")
    (license
      (list license:gpl2+
            (license:fsf-free "file://copyright/copyright.att"
                              "Standard ML of New Jersey Copyright License")
            (license "CAML Light 0.6 license"
                     "file://copyright/copyright.cl"
                     "This is a non-free license.")))))

;;; Moscow ML, including additional libraries:
;;; * Gdbm
;;; * Gdimage
;;; * Mysql
;;; * Polygdbm
;;; * Postgres
;;; * Regex
;;;
;;; Note that the additional libraries required lots of patches, and they
;;; compile with lots of warnings (especially Mysql), so caveat emptor.
(define-public mosml-full
  (package
    (inherit mosml)
    (name "mosml-full")
    (arguments
      (substitute-keyword-arguments (package-arguments mosml)
        ((#:phases phases)
         `(modify-phases ,phases
            (add-before 'build 'add-additional-libraries
              (lambda _
                (substitute* "Makefile"
                  (("BASISDYNLIB=intinf msocket munix" all)
                   (string-append all " mgd mgdbm mmysql mpq mregex")))
                (substitute* '("dynlibs/mgd/Makefile"
                               "dynlibs/mgdbm/Makefile"
                               "dynlibs/mmysql/Makefile"
                               "dynlibs/mpq/Makefile"
                               "dynlibs/mregex/Makefile")
                  (("^CFLAGS=[^\n]*" all)
                   (string-append all " -I../../runtime/")))

                ;; mgd.
                (substitute* "dynlibs/mgd/Makefile"
                  (("^GDDIR=[^\n]*")
                   (string-append "GDDIR=" (assoc-ref %build-inputs "gd")))
                  (("\\$\\{GDDIR\\}/libgd.a -L/usr/lib")
                   "-lgd"))
                (substitute* "dynlibs/mgd/mgd.c"
                  (("^#include <mlvalues.h>.*" all)
                   (string-append all "\n"
                                  "#include <memory.h>  /* For modify */\n"
                                  "#include <fail.h>    /* For failwith */"))
                  (("^[[:space:]]+flush\\(stdout\\);")
                   "fflush(stdout);"))

                ;; mgdbm.
                (substitute* "dynlibs/mgdbm/Makefile"
                  (("^GDBMLIBDIR=[^\n]*")
                   (string-append "GDBMLIBDIR="
                                  (assoc-ref %build-inputs "gdbm") "/lib"))
                  (("^GDBMINCDIR=[^\n]*")
                   (string-append "GDBMINCDIR="
                                  (assoc-ref %build-inputs "gdbm") "/include"))
                  (("\\$\\{GDBMLIBDIR\\}/libgdbm.a")
                   "-lgdbm"))

                ;; mmysql.
                (substitute* "dynlibs/mmysql/Makefile"
                  (("^MYSQLLIBDIR=[^\n]*")
                   (string-append "MYSQLLIBDIR="
                                  (assoc-ref %build-inputs "mysql") "/lib"))
                  (("^MYSQLINCDIR=[^\n]*")
                   (string-append "MYSQLINCDIR="
                                  (assoc-ref %build-inputs "mysql")
                                  "/include/mysql"))
                  (("-lnsl") "")
                  ;; Fix this error:
                  ;; ld: mmysql.o: relocation R_X86_64_32 against symbol
                  ;;     `dbresult_finalize' can not be used when making
                  ;;     a shared object; recompile with -fPIC
                  ;; collect2: error: ld returned 1 exit status
                  (("^CFLAGS=[^\n]*" all)
                   (string-append all " -fPIC")))
                (substitute* "dynlibs/mmysql/mmysql.c"
                  (("^#include <stdlib.h>" all)
                   (string-append all "\n"
                                  "#include <stdio.h>\n"
                                  "#include <string.h>"))
                  ;; Fix this error:
                  ;; mmysql.c: In function ‘dbresult_finalize’:
                  ;; mmysql.c:81:28: error: lvalue required as left operand of assignment
                  ;;      DBresult_val(dbresval) = NULL;
                  ;;                             ^
                  ;; mmysql.c:83:33: error: lvalue required as left operand of assignment
                  ;;      DBresultindex_val(dbresval) = NULL;
                  ;;                                  ^
                  (("DBresult_val\\(dbresval\\) = NULL;")
                   "MYSQL_RES *res = (MYSQL_RES*)(Field(dbresval, 1));\n
    res = NULL;")
                  (("DBresultindex_val\\(dbresval\\) = NULL;")
                   "MYSQL_ROW_OFFSET* val = (MYSQL_ROW_OFFSET*)(Field(dbresval, 2));\n
    val = NULL;"))

                  ;; mpq.
                  (substitute* "dynlibs/mpq/Makefile"
                    (("^PGSQLLIBDIR=[^\n]*")
                     (string-append "PGSQLLIBDIR="
                                    (assoc-ref %build-inputs "postgresql")
                                    "/lib"))
                    (("^PGSQLINCDIR=[^\n]*")
                     (string-append "PGSQLINCDIR="
                                    (assoc-ref %build-inputs "postgresql")
                                    "/include"))
                    (("\\$\\{PGSQLLIBDIR\\}/libpq.a")
                     "-lpq"))
                  (substitute* "dynlibs/mpq/mpq.c"
                    (("^#include <stdlib.h>" all)
                     (string-append all "\n#include <string.h>")))

                  ;; mregex.
                  (substitute* "dynlibs/mregex/regex-0.12/configure"
                    (("#!/bin/sh")
                     (string-append "#!" (which "sh")))
                    (("exec /bin/sh")
                     (string-append "exec " (which "sh"))))
                  (substitute* "dynlibs/mregex/regex-0.12/Makefile.in"
                    (("^SHELL[[:space:]]*=[[:space:]]*/bin/sh")
                     (string-append "SHELL=" (which "sh"))))
                  #t))))))
    (inputs `(,@(package-inputs mosml)
              ;; For mgd.
              ("gd" ,gd)
              ("libpng" ,libpng)
              ("zlib" ,zlib)
              ;; For mgdbm.
              ("gdbm" ,gdbm)
              ;; For mmysql.
              ("mysql" ,mysql)
              ;; For mpq.
              ("postgresql" ,postgresql)))
    (description
      (string-append
        (package-description mosml) "\n"
        "mosml-full includes these additional libraries:
@itemize
@item Gdbm
@item Gdimage
@item Mysql
@item Polygdbm
@item Postgres
@item Regex
@end itemize"))))
