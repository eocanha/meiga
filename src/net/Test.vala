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

using Upnp;
using GLib;

public class Test : GLib.Object {

  private UPNPStateContext *sc;
  private MainLoop mainloop;

  public Test() {
  }

  public void run() {
	mainloop = new MainLoop(null, false);

	sc = upnpstatecontext_new();
	upnp_get_public_ip(sc, on_complete_callback);

	/*
	  upnp_port_redirect(sc,
	  8001,
	  8001,
	  "192.168.1.10",
	  "Meiga",
	  5*60,
	  on_complete_callback);
	*/

	mainloop.run();

	upnpstatecontext_free(sc);
  }

  [CCode (instance_pos = -1)]
  public void on_complete_callback(bool success, string? result) {
	stdout.printf("%s: %s\n", (success?"Success":"Error"), result);
	mainloop.quit();
  }

  public static void main(string[] args) {
	new Test().run();
  }

}