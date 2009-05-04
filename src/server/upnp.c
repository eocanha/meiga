#include <upnp.h>
#include <libgupnp/gupnp-control-point.h>

#define CALLBACK_TIMEOUT (5*1000)

#define ACTION_NULL       0
#define ACTION_CONNECT    1
#define ACTION_ASK_IP     2
#define ACTION_REDIRECT   3
#define ACTION_RETURN     4

/** PRIVATE DECLARATION **/

struct _UPNPStateContext {
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
  gboolean cancel_callback;
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
};

static void
upnpstatecontext_clear (UPNPStateContext *sc);

static void
upnpstatecontext_set_task_name(UPNPStateContext *sc,
                               gchar *task_name);
static void
upnpstatecontext_set_action_seq(UPNPStateContext *sc,
                                gchar *action_seq);

static void
upnpstatecontext_set_result(UPNPStateContext *sc,
                            gchar *result);
static void
upnpstatecontext_push_timeout (UPNPStateContext *sc);

static void
upnpstatecontext_pop_timeout (UPNPStateContext *sc);

static void
upnpstatecontext_process_next_action (UPNPStateContext *sc);

static void
action_connect (UPNPStateContext *sc);

static void
action_ask_ip(UPNPStateContext *sc);

static void
action_redirect (UPNPStateContext *sc);

static void
action_return (UPNPStateContext *sc);

static void
callback_action_connect (GUPnPControlPoint *cp,
                         GUPnPServiceProxy *proxy,
                         gpointer           userdata);

static void
callback_action_ask_ip (GUPnPServiceProxy *proxy,
                        GUPnPServiceProxyAction *action,
                        gpointer user_data);

static void
callback_action_redirect (GUPnPServiceProxy *proxy,
                          GUPnPServiceProxyAction *action,
                          gpointer user_data);

static int
callback_timeout (gpointer userdata);

/** IMPLEMENTATION **/

UPNPStateContext *
upnpstatecontext_new (GMainLoop *mainloop)
{
  UPNPStateContext *sc = g_slice_new(UPNPStateContext);
  g_main_loop_ref(mainloop);
  sc->mainloop = mainloop;
  return sc;
}

static void
upnpstatecontext_clear (UPNPStateContext *sc)
{
  sc->last_callback_id = 0;
}

static void
upnpstatecontext_set_task_name(UPNPStateContext *sc,
                               gchar *task_name)
{
  g_free(sc->task_name);
  sc->task_name = g_strdup(task_name);
}

static void
upnpstatecontext_set_action_seq (UPNPStateContext *sc,
                                 gchar *action_seq)
{
  g_free(sc->action_seq);
  sc->action_seq = g_strdup(action_seq);
  sc->next_action = sc->action_seq;
}

static void
upnpstatecontext_set_result(UPNPStateContext *sc,
                            gchar *result)
{
  g_free(sc->result);
  sc->result = g_strdup(result);
}

void
upnpstatecontext_free (UPNPStateContext *sc)
{
  if (!sc) return;
  if (sc->cp) g_object_unref(sc->cp);
  if (sc->context) g_object_unref(sc->context);
  g_free(sc->task_name);
  g_free(sc->action_seq);
  g_free(sc->result);
  g_free(sc->internal_ip);
  g_free(sc->description);
  g_main_loop_unref(sc->mainloop);
  g_slice_free(UPNPStateContext, sc);
}

static void
upnpstatecontext_push_timeout (UPNPStateContext *sc)
{
  sc->cancel_timeout = FALSE;
  sc->cancel_callback = FALSE;
  (sc->num_running_timeouts)++;
  g_timeout_add (CALLBACK_TIMEOUT,
                 (GSourceFunc) callback_timeout,
                 (gpointer) sc);
}

static void
upnpstatecontext_pop_timeout (UPNPStateContext *sc)
{
  /* Tell the timeout to stop when it wakes up */
  sc->cancel_timeout = TRUE;
}

static void
upnpstatecontext_process_next_action (UPNPStateContext *sc)
{
  gchar next_action;
  gboolean asynch;

  while (*(sc->next_action)) {

    next_action = *(sc->next_action);
    (sc->next_action)++;

    g_debug("Processing next action: '%hhd'", next_action);

    switch (next_action) {
    case ACTION_CONNECT:
      action_connect(sc);
      asynch = TRUE;
      break;
    case ACTION_ASK_IP:
      action_ask_ip(sc);
      asynch = TRUE;
      break;
    case ACTION_REDIRECT:
      action_redirect(sc);
      asynch = TRUE;
      break;
    case ACTION_RETURN:
      action_return(sc);
      asynch = FALSE;
      break;
    default:
      g_error("Unhandled action: %u", next_action);
    }

    if (asynch) break;
  }
}

static void
action_connect (UPNPStateContext *sc)
{
  /* Only connect if the connection isn't already opened */
  if (!(sc->cp)) {
    /* Create a new GUPnP Context.  By here we are using the default GLib main
       context, and connecting to the current machine's default IP on an
       automatically generated port. */
    sc->context = gupnp_context_new (NULL, NULL, 0, NULL);

    /* Create a Control Point targeting WAN IP Connection services */
    sc->cp = gupnp_control_point_new
      (sc->context, "urn:schemas-upnp-org:service:WANIPConnection:1");

    sc->last_callback_id = g_signal_connect (sc->cp,
                                             "service-proxy-available",
                                             G_CALLBACK (callback_action_connect),
                                             (gpointer) sc);
    sc->proxy = NULL;

    /* Enqueue the watchdog timeout that will disable the callback if it */
    /* lasts too much */
    upnpstatecontext_push_timeout (sc);

    gssdp_resource_browser_set_active (GSSDP_RESOURCE_BROWSER (sc->cp), TRUE);
  }
}

static void
callback_action_connect (GUPnPControlPoint *cp,
                         GUPnPServiceProxy *proxy,
                         gpointer           userdata)
{
  UPNPStateContext *sc = (UPNPStateContext*) userdata;

  if (sc->cancel_callback) return;
  else upnpstatecontext_pop_timeout(sc);

  sc->proxy = proxy;
  upnpstatecontext_clear(sc);
  upnpstatecontext_process_next_action(sc);
}

static int
callback_timeout (gpointer userdata)
{
  UPNPStateContext *sc = (UPNPStateContext*) userdata;
  gboolean cancel_timeout = sc->cancel_timeout;

  (sc->num_running_timeouts)--;

  /* If this timeout isn't the last one, it should never be triggered */
  /* because if there are other timeouts enqueued it means that the   */
  /* action related to this timeout succeeded and this timeout has no */
  /* sense. It it's the last one, check cancel_timeout to see if it   */
  /* has been cancelled */
  if (sc->num_running_timeouts == 0) sc->cancel_timeout = FALSE;
  if (sc->num_running_timeouts > 0) return FALSE;
  else if (cancel_timeout) return FALSE;

  /* Timeout triggered: Disconnect signal callbacks and tell normal
  /* callbacks not to execute */
  if (sc->cp && sc->last_callback_id) {
    g_signal_handler_disconnect(sc->cp, sc->last_callback_id);
  }
  sc->cancel_callback = TRUE;

  /** Point the action sequence to the return action */
  while (*(sc->next_action) && *(sc->next_action)!=ACTION_RETURN)
    (sc->next_action)++;

  sc->result = g_strdup_printf("Timeout performing task '%s'", sc->task_name);
  sc->success = FALSE;

  upnpstatecontext_process_next_action(sc);

  return FALSE;
}

static void
action_ask_ip (UPNPStateContext *sc)
{
  GError *error = NULL;

  upnpstatecontext_clear(sc);

  gupnp_service_proxy_begin_action (sc->proxy,
                                    /* Action name and error location */
                                    "GetExternalIPAddress",
                                    callback_action_ask_ip,
                                    sc,
                                    &error,
                                    /* IN args */
                                    NULL);

  upnpstatecontext_push_timeout (sc);
}

static void
callback_action_ask_ip (GUPnPServiceProxy *proxy,
                        GUPnPServiceProxyAction *action,
                        gpointer user_data)
{
  UPNPStateContext *sc = (UPNPStateContext*) user_data;
  GError *error = NULL;
  gchar *ip = NULL;

  if (sc->cancel_callback) return;
  else upnpstatecontext_pop_timeout(sc);

  gupnp_service_proxy_end_action (proxy,
                                  action,
                                  &error,
                                  /* OUT args */
                                  "NewExternalIPAddress",
                                  G_TYPE_STRING, &ip,
                                  NULL);

  if (error == NULL) {
    sc->result = g_strdup_printf("External IP address is %s", ip);
    sc->success = TRUE;
    g_free (ip);
  } else {
    sc->result = g_strdup_printf("Error: %s", error->message);
    sc->success = FALSE;
    g_error_free (error);
  }
  upnpstatecontext_clear(sc);
  upnpstatecontext_process_next_action(sc);
}

static void
action_redirect (UPNPStateContext *sc)
{
  GError *error = NULL;
  gchar *new_external_port;
  gchar *new_internal_port;
  gchar *new_lease_duration;

  upnpstatecontext_clear(sc);

  new_external_port = g_strdup_printf("%u", sc->external_port);
  new_internal_port = g_strdup_printf("%u", sc->internal_port);
  new_lease_duration = g_strdup_printf("%lu", sc->sec_lease_duration);

  gupnp_service_proxy_begin_action (
    sc->proxy,
    "AddPortMapping",
    callback_action_redirect,
    sc,
    &error,
    /* IN args */
    "NewRemoteHost", G_TYPE_STRING, "",
    "NewExternalPort", G_TYPE_STRING, new_external_port,
    "NewProtocol", G_TYPE_STRING, "TCP",
    "NewInternalPort", G_TYPE_STRING, new_internal_port,
    "NewInternalClient", G_TYPE_STRING, sc->internal_ip,
    "NewEnabled", G_TYPE_STRING, "1",
    "NewPortMappingDescription", G_TYPE_STRING, sc->description,
    "NewLeaseDuration", G_TYPE_STRING, new_lease_duration,
    NULL);

  upnpstatecontext_push_timeout (sc);

  g_free(new_external_port);
  g_free(new_internal_port);
  g_free(new_lease_duration);
}

static void
callback_action_redirect  (GUPnPServiceProxy *proxy,
                           GUPnPServiceProxyAction *action,
                           gpointer user_data)
{
  UPNPStateContext *sc = (UPNPStateContext*) user_data;
  GError *error = NULL;

  if (sc->cancel_callback) return;
  else upnpstatecontext_pop_timeout(sc);

  gupnp_service_proxy_end_action (proxy,
                                  action,
                                  &error,
                                  /* OUT args */
                                  NULL);

  if (error == NULL) {
    sc->result = g_strdup_printf("Redirection *:%u --> %s:%u for %lu seconds performed",
                                 sc->external_port,
                                 sc->internal_ip,
                                 sc->internal_port,
                                 sc->sec_lease_duration);
    sc->success = TRUE;
  } else {
    sc->result = g_strdup_printf("Error: %s", error->message);
    sc->success = FALSE;
    g_error_free (error);
  }
  upnpstatecontext_clear(sc);
  upnpstatecontext_process_next_action(sc);
}

static void
action_return (UPNPStateContext *sc)
{
  if (sc->success) {
    g_printf("%s\n", sc->result);
    g_main_loop_quit(sc->mainloop);
  } else {
    g_printerr("%s\n", sc->result);
    g_main_loop_quit(sc->mainloop);
  }
}

gchar *
upnp_get_public_ip (UPNPStateContext *sc)
{
  upnpstatecontext_set_action_seq(sc, (gchar[]){
      ACTION_CONNECT,
        ACTION_ASK_IP,
        ACTION_RETURN,
        ACTION_NULL});
  upnpstatecontext_set_task_name(sc,"Get external IP address");
  upnpstatecontext_process_next_action(sc);
}

gchar *
upnp_port_redirect (UPNPStateContext *sc,
                    guint external_port,
                    guint internal_port,
                    gchar *internal_ip,
                    gchar *description,
                    gulong sec_lease_duration)
{
  sc->external_port = external_port;
  sc->internal_port = internal_port;
  g_free(sc->internal_ip);
  sc->internal_ip = g_strdup(internal_ip);
  g_free(sc->description);
  sc->description = g_strdup(description);
  sc->sec_lease_duration = sec_lease_duration;

  upnpstatecontext_set_action_seq(sc, (gchar[]){
      ACTION_CONNECT,
        ACTION_REDIRECT,
        ACTION_RETURN,
        ACTION_NULL});
  upnpstatecontext_set_task_name(sc,"Redirect port");
  upnpstatecontext_process_next_action(sc);
}

static int
main (int argc, char **argv)
{
  static GMainLoop *mainloop;
  UPNPStateContext *sc;

  /* Required initialisation */
  g_thread_init (NULL);
  g_type_init ();
  mainloop = g_main_loop_new (NULL, FALSE);

  sc = upnpstatecontext_new(mainloop);

  // upnp_get_public_ip(sc);

  upnp_port_redirect(sc,
                     8001,
                     8001,
                     "192.168.2.70",
                     "From Gnome to the world",
                     5*60);

  /* Enter the main loop */
  g_main_loop_run (mainloop);

  /* Clean up */
  g_main_loop_unref (mainloop);
  upnpstatecontext_free(sc);

  return 0;
}
