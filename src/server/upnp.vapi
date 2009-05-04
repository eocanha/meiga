[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Upnp {

  [CCode (cheader_filename = "upnp.h", cname = "UPNPStateContext")]
  public struct UPNPStateContext {
  }

  [CCode (cheader_filename = "upnp.h", cname = "upnpstatecontext_new")]
  UPNPStateContext *upnpstatecontext_new (GLib.MainLoop *mainloop);

  [CCode (cheader_filename = "upnp.h", cname = "upnpstatecontext_free")]
  void upnpstatecontext_free (UPNPStateContext *sc);

}
