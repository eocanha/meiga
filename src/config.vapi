/* Meiga - Lightweight and easy to use web file server for your desktop
 *
 * Copyright (C) 2009 Igalia, S.L.
 *
 * Authors:
 *
 * Igalia, S.L. <info@igalia.com>
 * Enrique Ocaña González <eocanha@igalia.com>
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
 */

[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Config {
  public const string DATADIR;
  public const string BINDIR;
  public const string GETTEXT_PACKAGE;
  public const string LOCALEDIR;
  public const string PACKAGE;
  public const string VERSION;
}

[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Posix {
  [SimpleType]
  [IntegerType (rank = 6)]
  [CCode (cname = "pid_t", default_value = "0", cheader_filename = "sys/types.h")]
  public struct pid_t {
  }
  [CCode (cheader_filename = "unistd.h")]
  public pid_t getpid ();

  [CCode (cname = "mode_t", cheader_filename = "sys/types.h")]
  public struct mode_t {
  }
  [CCode (cheader_filename = "fcntl.h")]
  public int open (string path, int oflag, mode_t mode=0);
  [CCode (cheader_filename = "unistd.h")]
  public ssize_t read (int fd, void* buf, size_t count);
  [CCode (cheader_filename = "unistd.h")]
  public int close (int fd);
}
