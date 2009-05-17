#ifndef _UPNP_
#define _UPNP_

#include <glib-object.h>

/** PUBLIC DECLARATION */

typedef struct _UPNPStateContext UPNPStateContext;

typedef void (*UpnpActionCompletedCallback) (gboolean success,
                                             const gchar *result,
                                             gpointer user_data);

UPNPStateContext *
upnpstatecontext_new ();

void
upnpstatecontext_free (UPNPStateContext *sc);

gchar *
upnp_get_public_ip (UPNPStateContext *sc,
                    UpnpActionCompletedCallback on_complete,
                    gpointer user_data);

gchar *
upnp_port_redirect (UPNPStateContext *sc,
                    guint external_port,
                    guint internal_port,
                    gchar *internal_ip,
                    gchar *description,
                    gulong sec_lease_duration,
                    UpnpActionCompletedCallback on_complete,
                    gpointer user_data);
#endif
