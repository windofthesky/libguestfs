(* virt-sysprep
 * Copyright (C) 2012 Red Hat Inc.
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
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *)

open Unix
open Printf

open Utils

module G = Guestfs

(* Finalize the list of operations modules. *)
let () = Sysprep_operation.bake ()

(* Command line argument parsing. *)
let prog = Filename.basename Sys.executable_name

let debug_gc, operations, g, selinux_relabel =
  let debug_gc = ref false in
  let domain = ref None in
  let dryrun = ref false in
  let files = ref [] in
  let format = ref "auto" in
  let libvirturi = ref "" in
  let operations = ref None in
  let selinux_relabel = ref `Auto in
  let trace = ref false in
  let verbose = ref false in

  let display_version () =
    let g = new G.guestfs () in
    let version = g#version () in
    printf "virt-sysprep %Ld.%Ld.%Ld%s\n"
      version.G.major version.G.minor version.G.release version.G.extra;
    exit 0
  and add_file file =
    let format = match !format with "auto" -> None | fmt -> Some fmt in
    files := (file, format) :: !files
  and set_domain dom =
    if !domain <> None then (
      eprintf "%s: --domain option can only be given once\n" prog;
      exit 1
    );
    domain := Some dom
  and dump_pod () =
    Sysprep_operation.dump_pod ();
    exit 0
  and dump_pod_options () =
    Sysprep_operation.dump_pod_options ();
    exit 0
  and set_enable ops =
    if !operations <> None then (
      eprintf "%s: --enable option can only be given once\n" prog;
      exit 1
    );
    if ops = "" then (
      eprintf "%s: you cannot pass an empty argument to --enable\n" prog;
      exit 1
    );
    let ops = string_split "," ops in
    let opset = List.fold_left (
      fun opset op_name ->
        try Sysprep_operation.add_to_set op_name opset
        with Not_found ->
          eprintf "%s: --enable: '%s' is not a known operation\n" prog op_name;
          exit 1
    ) Sysprep_operation.empty_set ops in
    operations := Some opset
  and force_selinux_relabel () =
    selinux_relabel := `Force
  and no_force_selinux_relabel () =
    selinux_relabel := `Never
  and list_operations () =
    Sysprep_operation.list_operations ();
    exit 0
  in

  let argspec = Arg.align [
    "-a",        Arg.String add_file,       "file Add disk image file";
    "--add",     Arg.String add_file,       "file Add disk image file";
    "-c",        Arg.Set_string libvirturi, "uri Set libvirt URI";
    "--connect", Arg.Set_string libvirturi, "uri Set libvirt URI";
    "--debug-gc", Arg.Set debug_gc,         " Debug GC and memory allocations (internal)";
    "-d",        Arg.String set_domain,     "domain Set libvirt guest name";
    "--domain",  Arg.String set_domain,     "domain Set libvirt guest name";
    "-n",        Arg.Set dryrun,            " Perform a dry run";
    "--dryrun",  Arg.Set dryrun,            " Perform a dry run";
    "--dry-run", Arg.Set dryrun,            " Perform a dry run";
    "--dump-pod", Arg.Unit dump_pod,        " Dump POD (internal)";
    "--dump-pod-options", Arg.Unit dump_pod_options, " Dump POD for options (internal)";
    "--enable",  Arg.String set_enable,     "operations Enable specific operations";
    "--format",  Arg.Set_string format,     "format Set format (default: auto)";
    "--list-operations", Arg.Unit list_operations, " List supported operations";
    "--selinux-relabel", Arg.Unit force_selinux_relabel, " Force SELinux relabel";
    "--no-selinux-relabel", Arg.Unit no_force_selinux_relabel, " Never do SELinux relabel";
    "-v",        Arg.Set verbose,           " Enable debugging messages";
    "--verbose", Arg.Set verbose,           " -\"-";
    "-V",        Arg.Unit display_version,  " Display version and exit";
    "--version", Arg.Unit display_version,  " -\"-";
    "-x",        Arg.Set trace,             " Enable tracing of libguestfs calls";
  ] @ Sysprep_operation.extra_args () in
  let anon_fun _ = raise (Arg.Bad "extra parameter on the command line") in
  let usage_msg =
    sprintf "\
%s: reset or unconfigure a virtual machine so clones can be made

 virt-sysprep [--options] -d domname

 virt-sysprep [--options] -a disk.img [-a disk.img ...]

A short summary of the options is given below.  For detailed help please
read the man page virt-sysprep(1).
"
      prog in
  Arg.parse argspec anon_fun usage_msg;

  (* Check -a and -d options. *)
  let files = !files in
  let domain = !domain in
  let libvirturi = match !libvirturi with "" -> None | s -> Some s in
  let add =
    match files, domain with
    | [], None ->
      eprintf "%s: you must give either -a or -d options\n" prog;
      eprintf "Read virt-sysprep(1) man page for further information.\n";
      exit 1
    | [], Some dom ->
      fun (g : Guestfs.guestfs) readonly ->
        let allowuuid = true in
        let readonlydisk = "ignore" (* ignore CDs, data drives *) in
        ignore (g#add_domain ~readonly ?libvirturi ~allowuuid ~readonlydisk dom)
    | _, Some _ ->
      eprintf "%s: you cannot give -a and -d options together\n" prog;
      eprintf "Read virt-sysprep(1) man page for further information.\n";
      exit 1
    | files, None ->
      fun g readonly ->
        List.iter (
          fun (file, format) ->
            g#add_drive_opts ~readonly ?format file
        ) files
  in

  (* Dereference the rest of the args. *)
  let debug_gc = !debug_gc in
  let dryrun = !dryrun in
  let operations = !operations in
  let selinux_relabel = !selinux_relabel in
  let trace = !trace in
  let verbose = !verbose in

  (* Connect to libguestfs. *)
  let g = new G.guestfs () in
  if trace then g#set_trace true;
  if verbose then g#set_verbose true;
  add g dryrun;
  g#launch ();

  debug_gc, operations, g, selinux_relabel

let () =
  (* Inspection. *)
  match Array.to_list (g#inspect_os ()) with
  | [] ->
    eprintf "%s: no operating systems were found in the guest image\n" prog;
    exit 1
  | roots ->
    List.iter (
      fun root ->
        (* Mount up the disks, like guestfish -i.
         * See [ocaml/examples/inspect_vm.ml].
         *)
        let mps = g#inspect_get_mountpoints root in
        let cmp (a,_) (b,_) = compare (String.length a) (String.length b) in
        let mps = List.sort cmp mps in
        List.iter (
          fun (mp, dev) ->
            try g#mount dev mp
            with Guestfs.Error msg -> eprintf "%s (ignored)\n" msg
        ) mps;

        (* Perform the operations. *)
        let flags = Sysprep_operation.perform_operations ?operations g root in

        (* Parse flags. *)
        let relabel = ref false in
        List.iter (function
        | `Created_files -> relabel := true
        ) flags;

        (* SELinux relabel? *)
        let relabel =
          match selinux_relabel, !relabel with
          | `Force, _ -> true
          | `Never, _ -> false
          | `Auto, relabel -> relabel in
        if relabel then (
          let typ = g#inspect_get_type root in
          let distro = g#inspect_get_distro root in
          match typ, distro with
          | "linux", ("fedora"|"rhel"|"redhat-based"
                         |"centos"|"scientificlinux") ->
            g#touch "/.autorelabel"
          | _ -> ()
        );

        (* Unmount everything in this guest. *)
        g#umount_all ()
    ) roots

(* Finished. *)
let () =
  g#close ();

  if debug_gc then
    Gc.compact ();

  exit 0
