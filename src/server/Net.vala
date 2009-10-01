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

  public static const int REDIRECTION_TYPE_NONE = 0;
  public static const int REDIRECTION_TYPE_UPNP = 1;
  public static const int REDIRECTION_TYPE_SSH  = 2;

  public static const int REDIRECTION_STATUS_NONE = 0;
  public static const int REDIRECTION_STATUS_PENDING = 1;
  public static const int REDIRECTION_STATUS_DONE = 2;
  public static const int REDIRECTION_STATUS_ERROR  = 3;

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
	owned get { string r; lock (worker) { r = (_url==null)?"":_url; } return r; }
	private set { lock (worker) { _url = value; } }
  }

  private int _previous_redirection_type;
  private int _redirection_type;
  public int redirection_type {
	owned get { int r; lock (worker) { r = _redirection_type; } return r; }
	set {
	  lock (worker) {
		// Don't allow type changing in the middle of a change process
		if (_redirection_status == REDIRECTION_STATUS_PENDING) return;
		_previous_redirection_type = _redirection_type;
		_redirection_type = value;
		Idle.add (forward_reload);
	  }
	}
  }

  private int _redirection_status;
  public int redirection_status {
	owned get { int r; lock (worker) { r = _redirection_status; } return r; }
	set { lock (worker) { _redirection_status = value; } }
  }

  private string _ssh_host;
  public string ssh_host {
	owned get { string r; lock (worker) { r = _ssh_host; } return r; }
	set { lock (worker) { _ssh_host = value; } }
  }

  private string _ssh_port;
  public string ssh_port {
	owned get { string r; lock (worker) { r = _ssh_port; } return r; }
	set { lock (worker) { _ssh_port = value; } }
  }

  private string _ssh_user;
  public string ssh_user {
	owned get { string r; lock (worker) { r = _ssh_user; } return r; }
	set { lock (worker) { _ssh_user = value; } }
  }

  private string _ssh_password;
  public string ssh_password {
	owned get { string r; lock (worker) { r = _ssh_password; } return r; }
	set { lock (worker) { _ssh_password = value; } }
  }

  private string _display = null;
  public string display {
	owned get { string r; lock (worker) { r = _display; } return r; }
	set { lock (worker) { _display = value; } }
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
	_previous_redirection_type = REDIRECTION_TYPE_NONE;
	_redirection_type = REDIRECTION_TYPE_NONE;
	_redirection_status = REDIRECTION_STATUS_NONE;
	ssh_host = "";
	ssh_user = "";
	display = "";
  }

  private void log(string msg) {
	if (_logger!=null) _logger.log(msg);
  }

  public bool forward_reload() {
	if (_redirection_type != _previous_redirection_type) {
	  forward_stop();
	  forward_start();
	}
	return false;
  }

  private void forward_start() {
	switch (redirection_type) {
	case REDIRECTION_TYPE_UPNP:
	  try {
		worker = Thread.create(forward_upnp_start, true);
	  } catch (SpawnError e) {
		log(_("Error spawning UPNP redirector process"));
	  } catch (ThreadError e) {
		log(_("Thread creating thread for UPNP redirector process"));
	  }
	  break;
	case REDIRECTION_TYPE_SSH:
	  try {
		worker = Thread.create(forward_ssh_start, true);
	  } catch (SpawnError e) {
		log(_("Error spawning UPNP redirector process"));
	  } catch (ThreadError e) {
		log(_("Thread creating thread for UPNP redirector process"));
	  }
	  break;
	}
  }

  private void forward_stop() {
	switch (_previous_redirection_type) {
	case REDIRECTION_TYPE_UPNP:
	  forward_upnp_stop();
	  break;
	case REDIRECTION_TYPE_SSH:
	  forward_ssh_stop();
	  break;
	}
  }

  private void *forward_upnp_start() {
	string internal_ip;
	string external_ip;
	string url;
	string txtout;
	string txterr;
	int result;
	int status;

	status = REDIRECTION_STATUS_PENDING;
	Idle.add( () => { set("redirection_status",REDIRECTION_STATUS_PENDING); return false; });

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
	  Idle.add( () => { set("redirection_status",REDIRECTION_STATUS_ERROR); return false; });
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
			status = REDIRECTION_STATUS_DONE;
		  }
		} else {
		  log(_("Redirection already present"));
		  status = REDIRECTION_STATUS_DONE;
		}
	  } else {
		log(_("External IP not found. Check that your router has UPnP enabled and working"));
		status = REDIRECTION_STATUS_ERROR;
	  }
	}

	url="http://%s:%d".printf(external_ip, port);

	set("internal_ip",internal_ip);
	set("external_ip",external_ip);
	set("url",url);
	set("redirection_status",status);

	return null;
  }

  public void forward_upnp_stop() {
	string txtout;
	string txterr;
	int result;
	int status;

	status = redirection_status;

	if (status == REDIRECTION_STATUS_DONE || status == REDIRECTION_STATUS_PENDING) {
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

	Idle.add( () => { set("redirection_status", REDIRECTION_STATUS_NONE); return false; });
  }

  private void *forward_ssh_start() {
	string internal_ip;
	string external_ip;
	string url;
	string txtout;
	string txterr;
	bool bresult;
	int result;
	int status;

	status = REDIRECTION_STATUS_PENDING;
	Idle.add( () => { set("redirection_status", REDIRECTION_STATUS_PENDING); return false; });

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
	  Idle.add( () => { set("redirection_status",REDIRECTION_STATUS_ERROR); return false; } );
	  return null;
	}

	external_ip = internal_ip;

	// Don't redirect if there's no valid internal IP
	// or remote host
	if (strcmp(internal_ip,"127.0.0.1")!=0) {
	  string sshcmd = Config.BINDIR+"/fwssh -r ";
	  string[] sshcmd_argv;

	  external_ip = ssh_host;
	  sshcmd += "%s %d %s %d".printf(ssh_host, port, internal_ip, port);

	  log(_("Using external IP: %s").printf(external_ip));
	  log(_("Creating SSH tunnel"));

	  sshcmd_argv = sshcmd.split_set(" ", 0);

	  Environment.set_variable("SSH_USER", ssh_user, true);
	  Environment.set_variable("SSH_PASSWORD", ssh_password, true);
	  Environment.set_variable("SSH_PORT", ssh_port, true);
	  Environment.set_variable("DISPLAY", display, true);

	  try {
		bresult = Process.spawn_sync (null,
							sshcmd_argv,
							null,
							SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL,
							null,
							null,
							null,
							out result);
		if (bresult && result == 0) {
		  log(_("Redirection performed"));
		  status = REDIRECTION_STATUS_DONE;
		} else {
		  log(_("Error creating SSH tunnel. Check config parameters and password."));
		  external_ip = internal_ip;
		  status = REDIRECTION_STATUS_ERROR;
		}
	  } catch (SpawnError e) {
		log(_("Error spawning SSH redirector process"));
		external_ip = internal_ip;
		status = REDIRECTION_STATUS_ERROR;
	  }
	}

	url="http://%s:%d".printf(external_ip, port);

	set("internal_ip",internal_ip);
	set("external_ip",external_ip);
	set("url",url);
	set("redirection_status",status);
	return null;
  }

  public void forward_ssh_stop() {
	string txtout;
	string txterr;
	int result;
	int status;

	status = redirection_status;

	if (status == REDIRECTION_STATUS_DONE ||
		status == REDIRECTION_STATUS_PENDING ||
		status == REDIRECTION_STATUS_ERROR) {
	  if (internal_ip != external_ip) {
		GLib.Process.spawn_command_line_sync(Config.BINDIR+"/fwssh -d %d".printf(port),
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

	Idle.add( () => { redirection_status = REDIRECTION_STATUS_NONE; return false; });
  }

}
