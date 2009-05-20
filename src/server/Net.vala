public class Net : GLib.Object {

  private string external_ip = null;
  private string internal_ip = null;

  public int port { get; set; default=8001; }
  public string url { get; private set; default=null; }

  public Net() {
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
	  stderr.printf("Found external IP: %s\n", external_ip);
	  GLib.Process.spawn_command_line_sync("fwupnp -q %d".printf(port),
										   out txtout,
										   out txterr,
										   out result);
	  if (result != 0) {
		stderr.printf("Creating redirection\n");
		GLib.Process.spawn_command_line_sync("fwupnp -r %d %d %s %s %d".printf(port,port,internal_ip,"FromGnomeToTheWorld",0),
											 out txtout,
											 out txterr,
											 out result);
		if (result == 0) {
		  stderr.printf("Redirection performed\n");
		}
	  } else {
		stderr.printf("Redirection already present\n");
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
		stderr.printf("Redirection removed\n");
	  }
	}
  }

}
