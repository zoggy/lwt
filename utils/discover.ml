(* Lightweight thread library for OCaml
 * http://www.ocsigen.org/lwt
 * Program discover
 * Copyright (C) 2010 Jérémie Dimino
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, with linking exceptions;
 * either version 2.1 of the License, or (at your option) any later
 * version. See COPYING file for details.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *)

(* Discover available features *)

open Printf

(* +-----------------------------------------------------------------+
   | Search path                                                     |
   +-----------------------------------------------------------------+ *)

(* List of search paths for header files, mostly for MacOS
   users. libev is installed by port systems into non-standard
   locations by default on MacOS.

   We use a hardcorded list of path + the ones from C_INCLUDE_PATH and
   LIBRARY_PATH.
*)

let ( // ) = Filename.concat

let default_search_paths =
  List.map (fun dir -> (dir // "include", dir // "lib")) [
    "/usr";
    "/usr/local";
    "/usr/pkg";
    "/opt";
    "/opt/local";
    "/sw";
    "/mingw";
  ]

let path_sep = if Sys.os_type = "Win32" then ';' else ':'

let split_path str =
  let len = String.length str in
  let rec aux i =
    if i >= len then
      []
    else
      let j = try String.index_from str i path_sep with Not_found -> len in
      String.sub str i (j - i) :: aux (j + 1)
  in
  aux 0

let rec replace_last path ~patt ~repl =
  let comp = Filename.basename path
  and parent = Filename.dirname path in
  if comp = patt then
    parent // repl
  else if parent = path then
    path
  else
    (replace_last parent ~patt ~repl) // comp

let search_paths =
  let get var f =
    try
      List.map f (split_path (Sys.getenv var))
    with Not_found ->
      []
  in
  List.flatten [
    get "C_INCLUDE_PATH" (fun dir -> (dir, replace_last dir ~patt:"include" ~repl:"lib"));
    get "LIBRARY_PATH" (fun dir -> (replace_last dir ~patt:"lib" ~repl:"include", dir));
    default_search_paths;
  ]

(* +-----------------------------------------------------------------+
   | Test codes                                                      |
   +-----------------------------------------------------------------+ *)

let caml_code = "
external test : unit -> unit = \"lwt_test\"
let () = test ()
"

let pthread_code = "
#include <caml/mlvalues.h>
#include <pthread.h>

CAMLprim value lwt_test(value Unit)
{
  pthread_create(0, 0, 0, 0);
  return Val_unit;
}
"

let libev_code = "
#include <caml/mlvalues.h>
#include <ev.h>

CAMLprim value lwt_test(value Unit)
{
  ev_default_loop(0);
  return Val_unit;
}
"

let fd_passing_code = "
#include <caml/mlvalues.h>
#include <sys/types.h>
#include <sys/socket.h>

CAMLprim value lwt_test(value Unit)
{
  struct msghdr msg;
  msg.msg_controllen = 0;
  msg.msg_control = 0;
  return Val_unit;
}
"

let getcpu_code = "
#include <caml/mlvalues.h>
#define _GNU_SOURCE
#include <sched.h>

CAMLprim value lwt_test(value Unit)
{
  sched_getcpu();
  return Val_unit;
}
"

let affinity_code = "
#include <caml/mlvalues.h>
#define _GNU_SOURCE
#include <sched.h>

CAMLprim value lwt_test(value Unit)
{
  sched_getaffinity(0, 0, 0);
  return Val_unit;
}
"

let eventfd_code = "
#include <caml/mlvalues.h>
#include <sys/eventfd.h>

CAMLprim value lwt_test(value Unit)
{
  eventfd(0, 0);
  return Val_unit;
}
"

let get_credentials_code struct_name = "
#define _GNU_SOURCE
#include <caml/mlvalues.h>
#include <sys/types.h>
#include <sys/socket.h>

CAMLprim value lwt_test(value Unit)
{
  struct " ^ struct_name ^ " cred;
  socklen_t cred_len = sizeof(cred);
  getsockopt(0, SOL_SOCKET, SO_PEERCRED, &cred, &cred_len);
  return Val_unit;
}
"

let get_peereid_code = "
#include <caml/mlvalues.h>
#include <sys/types.h>
#include <unistd.h>

CAMLprim value lwt_test(value Unit)
{
  uid_t euid;
  gid_t egid;
  getpeereid(0, &euid, &egid);
  return Val_unit;
}
"

let fdatasync_code = "
#include <caml/mlvalues.h>
#include <sys/unistd.h>

CAMLprim value lwt_test(value Unit)
{
  int (*fdatasyncp)(int) = fdatasync;
  fdatasyncp(0);
  return Val_unit;
}
"

let glib_code = "
#include <caml/mlvalues.h>
#include <glib.h>

CAMLprim value lwt_test(value Unit)
{
  g_main_context_dispatch(0);
  return Val_unit;
}
"

let netdb_reentrant_code = "
#define _POSIX_PTHREAD_SEMANTICS
#include <caml/mlvalues.h>
#include <netdb.h>
#include <stddef.h>

CAMLprim value lwt_test(value Unit)
{
  struct hostent *he;
  struct servent *se;
  he = gethostbyname_r((const char *)NULL, (struct hostent *)NULL,(char *)NULL, (int)0, (struct hostent **)NULL, (int *)NULL);
  he = gethostbyaddr_r((const char *)NULL, (int)0, (int)0,(struct hostent *)NULL, (char *)NULL, (int)0, (struct hostent **)NULL,(int *)NULL);
  se = getservbyname_r((const char *)NULL, (const char *)NULL,(struct servent *)NULL, (char *)NULL, (int)0, (struct servent **)NULL);
  se = getservbyport_r((int)0, (const char *)NULL,(struct servent *)NULL, (char *)NULL, (int)0, (struct servent **)NULL);
  pr = getprotoent_r((struct protoent *)NULL, (char *)NULL, (int)0, (struct protoent **)NULL);
  pr = getprotobyname_r((const char *)NULL, (struct protoent *)NULL, (char *)NULL, (int)0, (struct protoent **)NULL);
  pr = getprotobynumber_r((int)0, (struct protoent *)NULL, (char *)NULL, (int)0, (struct protoent **)NULL);

  return Val_unit;
}
"

let hostent_reentrant_code = "
#define _GNU_SOURCE
#include <stddef.h>
#include <caml/mlvalues.h>
#include <caml/config.h>
/* Helper functions for not re-entrant functions */
#if !defined(HAS_GETHOSTBYADDR_R) || (HAS_GETHOSTBYADDR_R != 7 && HAS_GETHOSTBYADDR_R != 8)
#define NON_R_GETHOSTBYADDR 1
#endif

#if !defined(HAS_GETHOSTBYNAME_R) || (HAS_GETHOSTBYNAME_R != 5 && HAS_GETHOSTBYNAME_R != 6)
#define NON_R_GETHOSTBYNAME 1
#endif

CAMLprim value lwt_test(value u)
{
  (void)u;
#if defined(NON_R_GETHOSTBYNAME) || defined(NON_R_GETHOSTBYNAME)
#error \"not available\"
#else
  return Val_unit;
#endif
}
"

let struct_ns_code conversion = "
#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <caml/mlvalues.h>

#define NANOSEC" ^ conversion ^ "

CAMLprim value lwt_test() {
  struct stat *buf;
  double a, m, c;
  a = (double)NANOSEC(buf, a);
  m = (double)NANOSEC(buf, m);
  c = (double)NANOSEC(buf, c);
  return Val_unit;
}
"

let bsd_mincore_code = "
#include <unistd.h>
#include <sys/mman.h>
#include <caml/mlvalues.h>

CAMLprim value lwt_test()
{
    int (*mincore_ptr)(const void*, size_t, char*) = mincore;
    return Val_int(mincore_ptr == mincore_ptr);
}
"

(* +-----------------------------------------------------------------+
   | Compilation                                                     |
   +-----------------------------------------------------------------+ *)

let ocamlc = ref "ocamlfind ocamlc"
let ext_obj = ref ".o"
let exec_name = ref "a.out"
let use_libev = ref true
let use_glib = ref false
let use_pthread = ref true
let use_unix = ref true
let os_type = ref "Unix"
let android_target = ref false
let ccomp_type = ref "cc"
let libev_default = ref true
let debug = ref (try Sys.getenv "DEBUG" = "y" with Not_found -> false)

let dprintf fmt =
  if !debug then
    (
      eprintf "DBG: ";
      kfprintf (fun oc -> fprintf oc "\n%!") stderr fmt
    )
  else ifprintf stderr fmt

let log_file = ref ""
let caml_file = ref ""

(* Search for a header file in standard directories. *)
let search_header header =
  let rec loop = function
    | [] ->
        None
    | (dir_include, dir_lib) :: dirs ->
        if Sys.file_exists (dir_include // header) then
          Some (dir_include, dir_lib)
        else
          loop dirs
  in
  loop search_paths

(* CFLAGS should not be passed to the linker. *)
let compile (opt, lib) stub_file =
  let cmd fmt = ksprintf (fun s ->
    dprintf "RUN: %s" s;
    Sys.command s = 0) fmt in
  let obj_file = Filename.chop_suffix stub_file ".c" ^ !ext_obj
  in
  (* First compile the .c file using -ocamlc and CFLAGS (opt) *)
  (cmd
    "%s -c %s %s -ccopt -o -ccopt %s >> %s 2>&1"
    !ocamlc
    (String.concat " " (List.map (fun x -> "-ccopt " ^ x) (List.map Filename.quote opt)))
    (Filename.quote stub_file)
    (Filename.quote obj_file)
    (Filename.quote !log_file))
  &&
  (* Now link the resulting .o with the LDFLAGS (lib) *)
  (cmd
    "%s -custom %s %s %s >> %s 2>&1"
    !ocamlc
    (Filename.quote obj_file)
    (Filename.quote !caml_file)
    (String.concat " " (List.map (sprintf "-cclib %s") lib))
    (Filename.quote !log_file))

let safe_remove file_name =
  if !debug then
    dprintf "DEBUG: Not removing %s\n" file_name
  else
    try
      Sys.remove file_name
    with exn ->
      ()

let test_code args stub_code =
  let stub_file, oc = Filename.open_temp_file "lwt_stub" ".c" in
  let cleanup () =
    safe_remove stub_file;
    safe_remove (Filename.chop_extension stub_file ^ !ext_obj)
  in
  try
    output_string oc stub_code;
    flush oc;
    close_out oc;
    let result = compile args stub_file in
    cleanup ();
    result
  with exn ->
    (try close_out oc with _ -> ());
    cleanup ();
    raise exn

let config = open_out "src/unix/lwt_config.h"
let config_ml = open_out "src/unix/lwt_config.ml"

let () =
  fprintf config "\
#ifndef __LWT_CONFIG_H
#define __LWT_CONFIG_H
"

let not_available = ref []

let test_feature ?(do_check = true) name macro test =
  if do_check then begin
    printf "testing for %s:%!" name;
    if test () then begin
      if macro <> "" then begin
        fprintf config "#define %s\n" macro;
        fprintf config_ml "let _%s = true\n" macro
      end;
      printf " %s available\n%!" (String.make (34 - String.length name) '.')
    end else begin
      if macro <> "" then begin
        fprintf config "//#define %s\n" macro;
        fprintf config_ml "let _%s = false\n" macro
      end;
      printf " %s unavailable\n%!" (String.make (34 - String.length name) '.');
      not_available := name :: !not_available
    end
  end else begin
    printf "not checking for %s\n%!" name;
    if macro <> "" then begin
      fprintf config "//#define %s\n" macro;
      fprintf config_ml "let _%s = false\n" macro
    end
  end

(* +-----------------------------------------------------------------+
   | pkg-config                                                      |
   +-----------------------------------------------------------------+ *)

let split str =
  let rec skip_spaces i =
    if i = String.length str then
      []
    else
      if str.[i] = ' ' then
        skip_spaces (i + 1)
      else
        extract i (i + 1)
  and extract i j =
    if j = String.length str then
      [String.sub str i (j - i)]
    else
      if str.[j] = ' ' then
        String.sub str i (j - i) :: skip_spaces (j + 1)
      else
        extract i (j + 1)
  in
  skip_spaces 0

let pkg_config flags =
  if ksprintf Sys.command "pkg-config %s > %s 2>&1" flags !log_file = 0 then begin
    let ic = open_in !log_file in
    let line = input_line ic in
    close_in ic;
    split line
  end else
    raise Exit

let pkg_config_flags name =
  try
    (* Get compile flags. *)
    let opt = ksprintf pkg_config "--cflags %s" name in
    (* Get linking flags. *)
    let lib =
      if !ccomp_type = "msvc" then
        (* With msvc we need to pass "glib-2.0.lib" instead of
           "-lglib-2.0" otherwise executables will fail. *)
        ksprintf pkg_config "--libs-only-L %s" name @ ksprintf pkg_config "--libs-only-l --msvc-syntax %s" name
      else
        ksprintf pkg_config "--libs %s" name
    in
    Some (opt, lib)
  with Exit ->
    None

let lib_flags env_var_prefix fallback =
  let get var = try Some (split (Sys.getenv var)) with Not_found -> None in
  match get (env_var_prefix ^ "_CFLAGS"), get (env_var_prefix ^ "_LIBS") with
    | Some opt, Some lib ->
        (opt, lib)
    | x ->
        let opt, lib = fallback () in
        match x with
          | Some opt, Some lib ->
              assert false
          | Some opt, None ->
              (opt, lib)
          | None, Some lib ->
              (opt, lib)
          | None, None ->
              (opt, lib)

(* +-----------------------------------------------------------------+
   | Entry point                                                     |
   +-----------------------------------------------------------------+ *)

let arg_bool r =
  Arg.Symbol (["true"; "false"],
              function
                | "true" -> r := true
                | "false" -> r := false
                | _ -> assert false)
let () =
  let args = [
    "-ocamlc", Arg.Set_string ocamlc, "<path> ocamlc";
    "-ext-obj", Arg.Set_string ext_obj, "<ext> C object files extension";
    "-exec-name", Arg.Set_string exec_name, "<name> name of the executable produced by ocamlc";
    "-use-libev", arg_bool use_libev, " whether to check for libev";
    "-use-glib", arg_bool use_glib, " whether to check for glib";
    "-use-pthread", arg_bool use_pthread, " whether to use pthread";
    "-use-unix", arg_bool use_unix, " whether to build lwt.unix";
    "-os-type", Arg.Set_string os_type, "<name> type of the target os";
    "-android-target", arg_bool android_target, "<name> compiles for Android";
    "-ccomp-type", Arg.Set_string ccomp_type, "<ccomp-type> C compiler type";
    "-libev_default", arg_bool libev_default, " whether to use the libev backend by default";
  ] in
  Arg.parse args ignore "check for external C libraries and available features\noptions are:";

  (* Check nothing if we do not build lwt.unix. *)
  if not !use_unix then exit 0;

  (* Put the caml code into a temporary file. *)
  let file, oc = Filename.open_temp_file "lwt_caml" ".ml" in
  caml_file := file;
  output_string oc caml_code;
  close_out oc;

  log_file := Filename.temp_file "lwt_output" ".log";

  (* Cleanup things on exit. *)
  at_exit (fun () ->
             (try close_out config with _ -> ());
             (try close_out config_ml with _ -> ());
             safe_remove !log_file;
             safe_remove !exec_name;
             safe_remove !caml_file;
             safe_remove (Filename.chop_extension !caml_file ^ ".cmi");
             safe_remove (Filename.chop_extension !caml_file ^ ".cmo"));

  let setup_data = ref [] in

  (* Test for pkg-config. *)
  test_feature ~do_check:(!use_libev || !use_glib) "pkg-config" ""
    (fun () ->
       ksprintf Sys.command "pkg-config --version > %s 2>&1" !log_file = 0);

  (* Not having pkg-config is not fatal. *)
  let have_pkg_config = !not_available = [] in
  not_available := [];

  let test_libev () =
    let opt, lib =
      lib_flags "LIBEV"
        (fun () ->
          match if have_pkg_config then pkg_config_flags "libev" else None with
            | Some (opt, lib) ->
                (opt, lib)
            | None ->
                match search_header "ev.h" with
                  | Some (dir_i, dir_l) ->
                      (["-I" ^ dir_i], ["-L" ^ dir_l; "-lev"])
                  | None ->
                      ([], ["-lev"]))
    in
    setup_data := ("libev_opt", opt) :: ("libev_lib", lib) :: !setup_data;
    test_code (opt, lib) libev_code
  in

  let test_pthread () =
    let opt, lib =
      if !android_target then ([], []) else
      lib_flags "PTHREAD" (fun () -> ([], ["-lpthread"]))
    in
    setup_data := ("pthread_opt", opt) :: ("pthread_lib", lib) :: !setup_data;
    test_code (opt, lib) pthread_code
  in

  let test_glib () =
    let opt, lib =
      lib_flags "GLIB"
        (fun () ->
          match if have_pkg_config then pkg_config_flags "glib-2.0" else None with
            | Some (opt, lib) ->
                (opt, lib)
            | None ->
                ([], ["-lglib-2.0"]))
    in
    setup_data := ("glib_opt", opt) :: ("glib_lib", lib) :: !setup_data;
    test_code (opt, lib) glib_code
  in

  let test_nanosecond_stat () =
    printf "testing for nanosecond stat support:%!";
    let conversions = [
      ("(buf, field) buf->st_##field##tim.tv_nsec",      "*tim.tv_nsec");
      ("(buf, field) buf->st_##field##timespec.tv_nsec", "*timespec.tv_nsec");
      ("(buf, field) buf->st_##field##timensec",         "*timensec");
    ] in
    let fallback = "(buf, field) 0.0" in
    let conversion = try
      let (conversion, desc) = List.find (fun (conversion, _desc) ->
        test_code ([], []) (struct_ns_code conversion)
      ) conversions in
      printf " %s %s\n%!" (String.make 11 '.') desc;
      conversion
    with Not_found -> begin
      printf " %s unavailable\n%!" (String.make 11 '.');
      fprintf config "#define NANOSEC%s\n" fallback;
      fallback
    end in
    fprintf config "#define NANOSEC%s\n" conversion
  in

  test_feature ~do_check:!use_libev "libev" "HAVE_LIBEV" test_libev;
  test_feature ~do_check:!use_pthread "pthread" "HAVE_PTHREAD" test_pthread;
  test_feature ~do_check:!use_glib "glib" "" test_glib;

  if !not_available <> [] then begin
    if not have_pkg_config then
      printf "Warning: the 'pkg-config' command is not available.";
    (* The missing library list should be printed on the last line, to avoid
       being trimmed by OPAM. The whole message should be kept to 10 lines. See
       https://github.com/ocsigen/lwt/issues/271. *)
    printf "
Some required C libraries were not found. If a C library <lib> is installed in a
non-standard location, set <LIB>_CFLAGS and <LIB>_LIBS accordingly. You may also
try 'ocaml setup.ml -configure --disable-<lib>' to avoid compiling support for
it. For example, in the case of libev missing:
    export LIBEV_CFLAGS=-I/opt/local/include
    export LIBEV_LIBS='-L/opt/local/lib -lev'
    (* or: *)  ocaml setup.ml -configure --disable-libev

Missing C libraries: %s
" (String.concat ", " !not_available);
    exit 1
  end;

  if !os_type <> "Win32" && not !use_pthread then begin
    printf "
No threading library available!

One is needed if you want to build lwt.unix.

Lwt can use pthread or the win32 API.
";
    exit 1
  end;

  let do_check = !os_type <> "Win32" in
  test_feature ~do_check "eventfd" "HAVE_EVENTFD" (fun () -> test_code ([], []) eventfd_code);
  test_feature ~do_check "fd passing" "HAVE_FD_PASSING" (fun () -> test_code ([], []) fd_passing_code);
  test_feature ~do_check:(do_check && not !android_target)
    "sched_getcpu" "HAVE_GETCPU" (fun () -> test_code ([], []) getcpu_code);
  test_feature ~do_check:(do_check && not !android_target)
    "affinity getting/setting" "HAVE_AFFINITY" (fun () -> test_code ([], []) affinity_code);
  test_feature ~do_check "credentials getting (Linux)" "HAVE_GET_CREDENTIALS_LINUX" (fun () -> test_code ([], []) (get_credentials_code "ucred"));
  test_feature ~do_check "credentials getting (NetBSD)" "HAVE_GET_CREDENTIALS_NETBSD" (fun () -> test_code ([], []) (get_credentials_code "sockcred"));
  test_feature ~do_check "credentials getting (OpenBSD)" "HAVE_GET_CREDENTIALS_OPENBSD" (fun () -> test_code ([], []) (get_credentials_code "sockpeercred"));
  test_feature ~do_check "credentials getting (FreeBSD)" "HAVE_GET_CREDENTIALS_FREEBSD" (fun () -> test_code ([], []) (get_credentials_code "cmsgcred"));
  test_feature ~do_check "credentials getting (getpeereid)" "HAVE_GETPEEREID" (fun () -> test_code ([], []) get_peereid_code);
  test_feature ~do_check "fdatasync" "HAVE_FDATASYNC" (fun () -> test_code ([], []) fdatasync_code);
  test_feature ~do_check:(do_check && not !android_target)
    "netdb_reentrant" "HAVE_NETDB_REENTRANT" (fun () -> test_code ([], []) netdb_reentrant_code);
  test_feature ~do_check "reentrant gethost*" "HAVE_REENTRANT_HOSTENT" (fun () -> test_code ([], []) hostent_reentrant_code);
  test_nanosecond_stat ();
  test_feature ~do_check "BSD mincore" "HAVE_BSD_MINCORE" (fun () ->
    test_code (["-Werror"], []) bsd_mincore_code);

  let get_cred_vars = [
    "HAVE_GET_CREDENTIALS_LINUX";
    "HAVE_GET_CREDENTIALS_NETBSD";
    "HAVE_GET_CREDENTIALS_OPENBSD";
    "HAVE_GET_CREDENTIALS_FREEBSD";
    "HAVE_GETPEEREID";
  ] in

  Printf.fprintf config "\
#if %s
#  define HAVE_GET_CREDENTIALS
#endif
"
    (String.concat " || " (List.map (Printf.sprintf "defined(%s)") get_cred_vars));

  Printf.fprintf config_ml
    "let _HAVE_GET_CREDENTIALS = %s\n"
    (String.concat " || " (List.map (fun s -> "_" ^ s) get_cred_vars));

  if !os_type = "Win32" then begin
    output_string config "#define LWT_ON_WINDOWS\n";
  end else begin
    output_string config "//#define LWT_ON_WINDOWS\n";
  end;
  if !android_target then begin
    output_string config_ml "let android = true\n"
  end else begin
    output_string config_ml "let android = false\n"
  end;
  if !libev_default then begin
    output_string config_ml "let libev_default = true\n"
  end else begin
    output_string config_ml "let libev_default = false\n"
  end;

  fprintf config "#endif\n";

  (* Our setup.data keys. *)
  let setup_data_keys = [
    "libev_opt";
    "libev_lib";
    "pthread_lib";
    "pthread_opt";
    "glib_opt";
    "glib_lib";
  ] in

  (* Load setup.data *)
  let setup_data_lines =
    match try Some (open_in "setup.data") with Sys_error _ -> None with
      | Some ic ->
          let rec aux acc =
            match try Some (input_line ic) with End_of_file -> None with
              | None ->
                  close_in ic;
                  acc
              | Some line ->
                  match try Some(String.index line '=') with Not_found -> None with
                    | Some idx ->
                        let key = String.sub line 0 idx in
                        if List.mem key setup_data_keys then
                          aux acc
                        else
                          aux (line :: acc)
                    | None ->
                        aux (line :: acc)
          in
          aux []
      | None ->
          []
  in

  (* Add flags to setup.data *)
  let setup_data_lines =
    List.fold_left
      (fun lines (name, args) ->
         sprintf "%s=%S" name (String.concat " " args) :: lines)
      setup_data_lines !setup_data
  in
  let oc = open_out "setup.data" in
  List.iter
    (fun str -> output_string oc str; output_char oc '\n')
    (List.rev setup_data_lines);
  close_out oc;

  close_out config;
  close_out config_ml;

  (* Generate stubs. *)
  print_endline "Generating C stubs...";
  exit (Sys.command "ocaml src/unix/gen_stubs.ml")
