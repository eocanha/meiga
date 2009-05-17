#include <stdlib.h>
#include <stdio.h>
#include <upnp.h>

void on_complete (gboolean success,
                  const gchar *result,
                  gpointer user_data) {
  GMainLoop *mainloop;
  mainloop = (GMainLoop*)user_data;
  g_printf("%s: %s\n", (success?"Success":"Error"), result);
  g_main_loop_quit(mainloop);
  exit(success?0:1);
}

static void print_usage(const gchar *progname) {
}

int
main (int argc, char *argv[])
{
  static GMainLoop *mainloop;
  UPNPStateContext *sc;

  /* Required initialisation */
  g_thread_init (NULL);
  g_type_init ();
  mainloop = g_main_loop_new (NULL, FALSE);

  sc = upnpstatecontext_new();

  if (argc == 2 && g_strcmp0(argv[1],"-i") == 0) {
    upnp_get_public_ip(sc,
                       on_complete,
                       mainloop);
  } else if (argc == 7 && g_strcmp0(argv[1],"-r") == 0) {
    guint external_port;
    guint internal_port;
    gchar *internal_ip;
    gchar *description;
    gulong sec_lease_duration;

    sscanf(argv[2],"%u",&external_port);
    sscanf(argv[3],"%u",&internal_port);
    internal_ip = argv[4];
    description = argv[5];
    sscanf(argv[6],"%lu",&sec_lease_duration);

    upnp_port_redirect(sc,
                       external_port,
                       internal_port,
                       internal_ip,
                       description,
                       sec_lease_duration,
                       on_complete,
                       mainloop);
  } else if (argc == 3 && g_strcmp0(argv[1],"-q") == 0) {
    guint external_port;
    sscanf(argv[2],"%u",&external_port);

    upnp_check_map(sc,
                   external_port,
                   on_complete,
                   mainloop);
  } else if (argc == 3 && g_strcmp0(argv[1],"-d") == 0) {
    guint external_port;
    sscanf(argv[2],"%u",&external_port);

    upnp_delete(sc,
                external_port,
                on_complete,
                mainloop);
  } else {
    g_printf("Usage: %s OPTION \n\n"
             "Options:\n"
             "-i"
             "\n\tQuery external IP\n"
             "-r "
             "external_port "
             "internal_port "
             "internal_ip "
             "description "
             "sec_lease_duration"
             "\n\tAdd redirection\n"
             "-q "
             "external_port"
             "\n\tQuery for redirection"
             "-d "
             "external_port"
             "\n\tDelete existing redirection"
             "\n\n"
             "Exit status: "
             "0 = Success, "
             "1 = Request failure, "
             "2 = Syntax error\n",
             argv[0]);
    exit(2);
  }

  /* Enter the main loop */
  g_main_loop_run (mainloop);

  /* Clean up */
  g_main_loop_unref (mainloop);
  upnpstatecontext_free(sc);

  exit(0);
}
