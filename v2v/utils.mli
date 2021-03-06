(* virt-v2v
 * Copyright (C) 2009-2016 Red Hat Inc.
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

(** Utilities used in virt-v2v only. *)

val drive_name : int -> string
val drive_index : string -> int

val shell_unquote : string -> string
(** If the string looks like a shell quoted string, then attempt to
    unquote it.

    This is just intended to deal with quoting in configuration files
    (like ones under /etc/sysconfig), and it doesn't deal with some
    situations such as $variable interpolation. *)

val kvm_arch : string -> string
(** Map guest architecture found by inspection to the architecture
    that KVM must emulate.  Note for x86 we assume a 64 bit hypervisor. *)

val qemu_supports_sound_card : Types.source_sound_model -> bool
(** Does qemu support the given sound card? *)

val find_uefi_firmware : string -> Uefi.uefi_firmware
(** Find the UEFI firmware for the guest architecture.
    This cannot return an error, it calls [error] and fails instead. *)

val compare_app2_versions : Guestfs.application2 -> Guestfs.application2 -> int
(** Compare two app versions. *)

val du : string -> int64
(** Return the true size of a file in bytes, including any wasted
    space caused by internal fragmentation (the overhead of using
    blocks).

    This can raise either [Failure] or [Invalid_argument] in case
    of errors. *)
