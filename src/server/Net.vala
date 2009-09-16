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

using Config;

public class Net : GLib.Object {

  private weak Thread worker = null;

  private string _external_ip;
  public string external_ip {
	private owned get { string r; lock (worker) { r = _external_ip; } return r; }
	private set { lock (worker) { _external_ip = value; } }
  }

  private string _internal_ip;
  public string internal_ip {
	private owned get { string r; lock (worker) { r = _internal_ip; } return r; }
	private set { lock (worker) { _internal_ip = value; } }
  }

  private int _port;
  public int port {
	owned get { int r; lock (worker) { r = _port; } return r; }
	set { lock (worker) { _port = value; } }
  }

  private string _url = null;
  public string url {
	owned get { string r; lock (worker) { r = _url; } return r; }
	private set { lock (worker) { _url = value; } }
  }

  private Log _logger;
  public Log logger {
	private owned get { Log r; lock (worker) { r = _logger; } return r; }
	set { lock (worker) { _logger = value; } }
  }

  public Net() {
	port = 8001;
	url = null;
	logger = null;
  }

  private void log(string msg) {
	if (_logger!=null) _logger.log(msg);
  }

  public void forward_start() {
	try {
	  worker = Thread.create(forward_upnp_start, true);
	} catch (SpawnError e) {
	  debug("Spawn error");
	} catch (ThreadError e) {
	  debug("Thread error");
	}
  }

  public void forward_stop() {
	forward_upnp_stop();
  }

  private void *forward_upnp_start() {
	string internal_ip;
	string external_ip;
	string url;
	string txtout;
	string txterr;
	int result;

	GLib.Process.spawn_command_line_sync(Config.BINDIR+"/fwlocalip",
										 out txtout,
										 out txterr,
										 out result);

	if (result == 0) {
	  internal_ip = txtout.chomp();
	  log(_("Found internal IP: %s").printf(internal_ip));
	} else {
	  log(_("Local IP not found"));
	  internal_ip = "127.0.0.1";
	  return null;
	}

	external_ip = internal_ip;

	// Don't redirect if there's no valid internal IP
	if (strcmp(internal_ip,"127.0.0.1")!=0) {
	  GLib.Process.spawn_command_line_sync(Config.BINDIR+"/fwupnp -i",
										   out txtout,
										   out txterr,
										   out result);
	  txtout = txtout.chomp();

	  if (result == 0 && strcmp(txtout,"")!=0
		  && strcmp(txtout,"(null)")!=0) {
		external_ip = txtout;
		log(_("Found external IP: %s").printf(external_ip));
		GLib.Process.spawn_command_line_sync(Config.BINDIR+"/fwupnp -q %d".printf(port),
											 out txtout,
											 out txterr,
											 out result);
		if (result != 0) {
		  log(_("Creating redirection"));
		  GLib.Process.spawn_command_line_sync(Config.BINDIR+"/fwupnp -r %d %d %s %s %d".printf(port,port,internal_ip,"Meiga",0),
											   out txtout,
											   out txterr,
											   out result);
		  if (result == 0) {
			log(_("Redirection performed"));
		  }
		} else {
		  log(_("Redirection already present"));
		}
	  } else {
		log(_("External IP not found. Check that your router has UPnP enabled and working"));
	  }
	}

	url="http://%s:%d".printf(external_ip, port);

	set("internal_ip",internal_ip);
	set("external_ip",external_ip);
	set("url",url);

	return null;
  }

  public void forward_upnp_stop() {
	string txtout;
	string txterr;
	int result;

	if (internal_ip != external_ip) {
	  GLib.Process.spawn_command_line_sync(Config.BINDIR+"/fwupnp -d %d".printf(port),
										   out txtout,
										   out txterr,
										   out result);
	  if (result == 0) {
		log(_("Redirection removed"));
	  } else {
		log(_("Unable to remove redirection"));
	  }
	}
  }

}
