#ifndef _UPNP_
#define _UPNP_

#include <glib-object.h>

/** PUBLIC DECLARATION */

typedef struct _UPNPStateContext UPNPStateContext;

UPNPStateContext *
upnpstatecontext_new ();

void
upnpstatecontext_free (UPNPStateContext *sc);

gchar *
upnp_get_public_ip (UPNPStateContext *sc);

gchar *
upnp_port_redirect (UPNPStateContext *sc,
                    guint external_port,
                    guint internal_port,
                    gchar *internal_ip,
                    gchar *description,
                    gulong sec_lease_duration);

#endif
