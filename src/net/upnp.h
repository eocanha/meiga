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

void
upnpstatecontext_set_iface (UPNPStateContext *sc,
                              gchar *iface);

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

gchar *
upnp_check_map (UPNPStateContext *sc,
                guint external_port,
                UpnpActionCompletedCallback on_complete,
                gpointer user_data);

gchar *
upnp_delete (UPNPStateContext *sc,
             guint external_port,
             UpnpActionCompletedCallback on_complete,
             gpointer user_data);

#endif
