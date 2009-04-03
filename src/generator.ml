#!/usr/bin/ocamlrun ocaml
(* libguestfs
 * Copyright (C) 2009 Red Hat Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 *
 * This script generates a large amount of code and documentation for
 * all the daemon actions.  To add a new action there are only two
 * files you need to change, this one to describe the interface, and
 * daemon/<somefile>.c to write the implementation.
 *)

#load "unix.cma";;

open Printf

type styles =
  | Int_Void		(* int foo (guestfs_h); *)
  | Int_String		(* int foo (guestfs_h, const char * ); *)
  | Int_StringString	(* int foo (guestfs_h, const char *, const char * ); *)

let functions = [
  ("mount", Int_StringString, [|"device"; "mountpoint"|],
   "Mount a guest disk at a position in the filesystem",
   "\
Mount a guest disk at a position in the filesystem.  Block devices
are named C</dev/sda>, C</dev/sdb> and so on, as they were added to
the guest.  If those block devices contain partitions, they will have
the usual names (eg. C</dev/sda1>).  Also LVM C</dev/VG/LV>-style
names can be used.

The rules are the same as for L<mount(2)>:  A filesystem must
first be mounted on C</> before others can be mounted.  Other
filesystems can only be mounted on directories which already
exist.");

  ("sync", Int_Void, [||],
   "Sync disks, writes are flushed through to the disk image",
   "\
This syncs the disk, so that any writes are flushed through to the
underlying disk image.

You should always call this if you have modified a disk image, before
calling C<guestfs_close>.");

  ("touch", Int_String, [|"path"|],
   "Update file timestamps or create a new file",
   "\
Touch acts like the L<touch(1)> command.  It can be used to
update the filesystems on a file, or, if the file does not exist,
to create a new zero-length file.");
]

(* 'pr' prints to the current output file. *)
let chan = ref stdout
let pr fs = ksprintf (output_string !chan) fs

type comment_style = CStyle | HashStyle | OCamlStyle
type license = GPLv2 | LGPLv2

(* Generate a header block in a number of standard styles. *)
let rec generate_header comment license =
  let c = match comment with
    | CStyle ->     pr "/* "; " *"
    | HashStyle ->  pr "# ";  "#"
    | OCamlStyle -> pr "(* "; " *" in
  pr "libguestfs generated file\n";
  pr "%s WARNING: This file is generated by 'src/generator.ml'.\n" c;
  pr "%s Any changes you make to this file will be lost.\n" c;
  pr "%s\n" c;
  pr "%s Copyright (C) 2009 Red Hat Inc.\n" c;
  pr "%s\n" c;
  (match license with
   | GPLv2 ->
       pr "%s This program is free software; you can redistribute it and/or modify\n" c;
       pr "%s it under the terms of the GNU General Public License as published by\n" c;
       pr "%s the Free Software Foundation; either version 2 of the License, or\n" c;
       pr "%s (at your option) any later version.\n" c;
       pr "%s\n" c;
       pr "%s This program is distributed in the hope that it will be useful,\n" c;
       pr "%s but WITHOUT ANY WARRANTY; without even the implied warranty of\n" c;
       pr "%s MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n" c;
       pr "%s GNU General Public License for more details.\n" c;
       pr "%s\n" c;
       pr "%s You should have received a copy of the GNU General Public License along\n" c;
       pr "%s with this program; if not, write to the Free Software Foundation, Inc.,\n" c;
       pr "%s 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.\n" c;

   | LGPLv2 ->
       pr "%s This library is free software; you can redistribute it and/or\n" c;
       pr "%s modify it under the terms of the GNU Lesser General Public\n" c;
       pr "%s License as published by the Free Software Foundation; either\n" c;
       pr "%s version 2 of the License, or (at your option) any later version.\n" c;
       pr "%s\n" c;
       pr "%s This library is distributed in the hope that it will be useful,\n" c;
       pr "%s but WITHOUT ANY WARRANTY; without even the implied warranty of\n" c;
       pr "%s MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU\n" c;
       pr "%s Lesser General Public License for more details.\n" c;
       pr "%s\n" c;
       pr "%s You should have received a copy of the GNU Lesser General Public\n" c;
       pr "%s License along with this library; if not, write to the Free Software\n" c;
       pr "%s Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA\n" c;
  );
  (match comment with
   | CStyle -> pr " */\n"
   | HashStyle -> ()
   | OCamlStyle -> pr " *)\n"
  );
  pr "\n"

(* Generate the pod documentation for the C API. *)
and generate_pod () =
  List.iter (
    fun (shortname, style, params, _, longdesc) ->
      let name = "guestfs_" ^ shortname in
      pr "=head2 %s\n\n" name;
      pr " ";
      generate_prototype ~extern:false name style params;
      pr "\n\n";
      pr "%s\n\n" longdesc
  ) functions

(* Generate the protocol (XDR) file. *)
and generate_xdr () =
  generate_header CStyle LGPLv2;
  List.iter (
    fun (shortname, style, params, _, longdesc) ->
      let name = "guestfs_" ^ shortname in
      pr "/* %s */\n" name;


      pr "\n";
  ) functions

(* Generate a single line prototype. *)
and generate_prototype ~extern ?(semi = true) ?(handle = "handle")
    name style params =
  if extern then pr "extern ";
  (match style with
   | Int_Void | Int_String | Int_StringString -> pr "int "
  );
  pr "%s (guestfs_h *%s" name handle;
  (match style with
   | Int_Void -> ()
   | Int_String ->
       pr ", const char *%s" params.(0)
   | Int_StringString ->
       pr ", const char *%s" params.(0);
       pr ", const char *%s" params.(1)
  );
  pr ")";
  if semi then pr ";"

let output_to filename =
  let filename_new = filename ^ ".new" in
  chan := open_out filename_new;
  let close () =
    close_out !chan;
    chan := stdout;
    Unix.rename filename_new filename
  in
  close

(* Main program. *)
let () =
  let close = output_to "guestfs-actions.pod" in
  generate_pod ();
  close ();

  let close = output_to "src/guestfs_protocol.x" in
  generate_xdr ();
  close ();
