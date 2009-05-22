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