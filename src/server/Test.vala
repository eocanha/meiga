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
	upnp_get_public_ip(sc);

	/*
	upnp_port_redirect(sc,
					   8001,
					   8001,
					   "192.168.1.122",
					   "From Gnome to the world",
					   5*60);
	*/

	mainloop.run();

	upnpstatecontext_free(sc);
  }

  public static void main(string[] args) {
	new Test().run();
  }

}