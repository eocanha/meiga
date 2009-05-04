using Upnp;

public class Test : GLib.Object {

  private UPNPStateContext *context;

  public Test() {
	context = upnpstatecontext_new(null);
  }

  public static void main(string[] args) {
	Test t = new Test();
  }

}