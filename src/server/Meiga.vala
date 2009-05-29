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

using GLib;

[DBus (name = "com.igalia.Meiga", signals="has_changed")]
public class Meiga : GLib.Object {
  private MeigaServer server;
  public signal void has_changed();

  public Meiga(MeigaServer server) {
	this.server = server;
  }

  public void register_path(string real_path, string logical_path) {
	server.register_path(real_path,logical_path);
	has_changed();
  }

  public void unregister_path(string logical_path) {
	server.unregister_path(logical_path);
	has_changed();
  }

  public HashTable<string,string> get_paths() {
	return server.get_paths();
  }

  public string get_paths_as_string() {
	HashTable<string,string> t=server.get_paths();
	string result="";
	foreach (string k in t.get_keys()) {
	  string v=t.lookup(k);
	  result+=k+"\t"+v+"\n";
	}
	return result;
  }

  public string get_public_url() {
	return server.get_public_url();
  }

  public void shutdown() {
	server.shutdown();
  }

}