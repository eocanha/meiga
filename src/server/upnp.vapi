[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Upnp {

  [CCode (cheader_filename = "upnp.h", cname = "UPNPStateContext")]
  public struct UPNPStateContext {
  }

  [CCode (cheader_filename = "upnp.h", cname = "upnpstatecontext_new")]
  UPNPStateContext *upnpstatecontext_new ();

  [CCode (cheader_filename = "upnp.h", cname = "upnpstatecontext_free")]
  void upnpstatecontext_free (UPNPStateContext *sc);

  [CCode (cheader_filename = "upnp.h", cname = "upnp_get_public_ip")]
  void upnp_get_public_ip (UPNPStateContext *sc);

  [CCode (cheader_filename = "upnp.h", cname = "upnp_port_redirect")]
  void upnp_port_redirect (UPNPStateContext *sc,
						   int external_port,
						   int internal_port,
						   string internal_ip,
						   string description,
						   ulong sec_lease_duration);

}
