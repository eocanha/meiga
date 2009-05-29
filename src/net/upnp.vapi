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

[CCode (cprefix = "", lower_case_cprefix = "")]
namespace Upnp {

  [CCode (cheader_filename = "upnp.h", cname = "UPNPStateContext")]
  public struct UPNPStateContext {
  }

  [CCode (cheader_filename = "upnp.h", cname = "upnpstatecontext_new")]
  UPNPStateContext *upnpstatecontext_new ();

  [CCode (cheader_filename = "upnp.h", cname = "upnpstatecontext_free")]
  void upnpstatecontext_free (UPNPStateContext *sc);

  [CCode (cheader_filename = "upnp.h", cname = "UpnpActionCompletedCallback")]
  public delegate void UpnpActionCompletedCallback (bool success, string result);

  [CCode (cheader_filename = "upnp.h", cname = "upnp_get_public_ip")]
  void upnp_get_public_ip (UPNPStateContext *sc,
						   UpnpActionCompletedCallback? on_complete);

  [CCode (cheader_filename = "upnp.h", cname = "upnp_port_redirect")]
  void upnp_port_redirect (UPNPStateContext *sc,
						   int external_port,
						   int internal_port,
						   string internal_ip,
						   string description,
						   ulong sec_lease_duration,
						   UpnpActionCompletedCallback? on_complete);

}
