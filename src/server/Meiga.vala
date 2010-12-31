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

[DBus (name = "com.igalia.Meiga", signals="model_changed, log_changed")]
public class Meiga : GLib.Object {
  private MeigaServer server;
  public signal void model_changed();
  public signal void log_changed();

  public Meiga(MeigaServer server) {
	this.server = server;
	if (this.server.logger!=null) {
	  // Forward logger changed signal to our remote observers
	  this.server.logger.changed += (o) => { this.log_changed(); };
	}
	// Forward model changed signal to our remote observers
	this.server.model_changed += (o) => { this.model_changed(); };
  }

  public void register_path(string real_path, string logical_path) {
	server.register_path(real_path,logical_path);
	model_changed();
  }

  public void unregister_path(string logical_path) {
	server.unregister_path(logical_path);
	model_changed();
  }

  public uint get_gui_pid() {
	return server.gui_pid;
  }

  public string get_display() {
	return server.display;
  }

  public void register_gui(uint gui_pid, string display) {
	server.register_gui(gui_pid, display);
  }

  public HashTable<string,string> get_paths() {
	return server.get_paths();
  }

  public string get_paths_as_string() {
	HashTable<string,string> t=server.get_paths();
	List<weak string> keys=t.get_keys().copy();
	keys.sort(GLib.strcmp);
	string result="";
	foreach (weak string k in keys) {
	  string v=t.lookup(k);
	  result+=k+"\t"+v+"\n";
	}
	return result;
  }

  public string get_public_url() {
	return server.get_public_url();
  }

  public int get_redirection_type() {
	return server.get_redirection_type();
  }

  public void set_redirection_type(int redirection_type) {
	server.set_redirection_type(redirection_type);
  }

  public int get_redirection_status() {
	return server.get_redirection_status();
  }

  public uint get_port() {
	return server.port;
  }

  public void set_port(uint port) {
	server.port=port;
  }

  public bool get_ssl() {
	return server.ssl;
  }

  public void set_ssl(bool ssl) {
	server.ssl=ssl;
  }

  public string get_auth_user() {
	return server.auth_user;
  }

  public void set_auth_user(string auth_user) {
	server.auth_user = auth_user;
  }

  public string get_auth_md5passwd() {
	return server.auth_md5passwd;
  }

  public void set_auth_md5passwd(string auth_md5passwd) {
	server.auth_md5passwd = auth_md5passwd;
  }

  public void set_ssh_host(string ssh_host) {
	server.set_ssh_host(ssh_host);
  }

  public void set_ssh_port(string ssh_port) {
	server.set_ssh_port(ssh_port);
  }

  public void set_ssh_user(string ssh_user) {
	server.set_ssh_user(ssh_user);
  }

  public void set_ssh_password(string ssh_password) {
	server.set_ssh_password(ssh_password);
  }

  public void shutdown() {
	server.shutdown();
  }

  public string get_pending_log(uint start) {
	string result;

	if (server.logger!=null) {
	  result = server.logger.get_pending(start);
	} else if (start==0) {
	  result = _("--- No log available ---");
	} else {
	  result = "";
	}

	return result;
  }

  public string get_requests_stats() {
	return server.get_requests_stats();
  }

}