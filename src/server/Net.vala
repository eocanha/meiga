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

public class Net : GLib.Object {

  private string external_ip = null;
  private string internal_ip = null;

  public int port { get; set; default=8001; }
  public string url { get; private set; default=null; }
  public Log logger { private get; set; default=null; }

  public Net() {
  }

  private void log(string msg) {
	if (logger!=null) logger.log(msg);
  }

  public void forward_start() {
	string txtout;
	string txterr;
	int result;

	GLib.Process.spawn_command_line_sync("fwlocalip",
										 out txtout,
										 out txterr,
										 out result);

	if (result == 0) {
	  internal_ip = txtout.chomp();
	} else {
	  // Don't continue if there's no valid internal IP
	  return;
	}

	external_ip = internal_ip;

	GLib.Process.spawn_command_line_sync("fwupnp -i",
										 out txtout,
										 out txterr,
										 out result);

	if (result == 0 && strcmp(txtout,"(null)")!=0) {
	  external_ip = txtout;
	  log("Found external IP: %s".printf(external_ip));
	  GLib.Process.spawn_command_line_sync("fwupnp -q %d".printf(port),
										   out txtout,
										   out txterr,
										   out result);
	  if (result != 0) {
		log("Creating redirection");
		GLib.Process.spawn_command_line_sync("fwupnp -r %d %d %s %s %d".printf(port,port,internal_ip,"Meiga",0),
											 out txtout,
											 out txterr,
											 out result);
		if (result == 0) {
		  log("Redirection performed");
		}
	  } else {
		log("Redirection already present");
	  }

	}

	url="http://%s:%d".printf(external_ip, port);
  }

  public void forward_stop() {
	string txtout;
	string txterr;
	int result;

	if (internal_ip != external_ip) {
	  GLib.Process.spawn_command_line_sync("fwupnp -d %d".printf(port),
										   out txtout,
										   out txterr,
										   out result);
	  if (result == 0) {
		log("Redirection removed");
	  }
	}
  }

}
