#ifndef _UPNP_
#define _UPNP_

#include <libgupnp/gupnp-control-point.h>

/** PUBLIC DECLARATION */

typedef struct {
  /* GUPnP management */
  GUPnPContext *context;
  GUPnPControlPoint *cp;
  GUPnPServiceProxy *proxy;
  GMainLoop *mainloop;

  /* Action sequence management */
  gchar *action_seq;
  gchar *next_action; /* Pointer to somewhere inside action_seq */
  gchar *task_name;
  gulong last_callback_id;
  gboolean cancel_timeout;
  gint num_running_timeouts;

  /* Parameter management */
  guint external_port;
  guint internal_port;
  gchar *internal_ip;
  gchar *description;
  gulong sec_lease_duration;

  /* Result management */
  gchar *result;
  gboolean success;
} UPNPStateContext;

UPNPStateContext *
upnpstatecontext_new (GMainLoop *mainloop);

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
