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

using GLib;
using Gtk;
using Gdk;
using Config;

const string UI_FILENAME = "gui.ui";
const string UI_PATH = "ui:"+Config.DATADIR+"/meiga/ui";

public class Gui : GLib.Object {

  // Private attributes
  private Gtk.Builder builder;
  private Gtk.MenuShell menu;
  private Gtk.Menu systraymenu;
  private Gtk.Window top;
  private Gtk.Window adddialog;
  private Gtk.Window aboutdialog;
  private Gtk.StatusIcon systray;
  private Gtk.Action systraymenu_restore;
  private Gtk.TreeView files;
  private Gtk.Statusbar statusbar;
  private Gtk.FileChooserButton localdirectory;
  private Gtk.Entry shareas;
  private Gtk.TextView logtext;
  private Gtk.Clipboard clipboard;

  private Gtk.ListStore model;
  private string string_model;
  private string public_url;
  private string preferred_share;
  private string invitation;
  private uint lastlog;

  private dynamic DBus.Object _remote = null;
  private dynamic DBus.Object remote {
    // Maybe remote DBUS service isn't immediately available, so by using
    // this lazy init we give it the opportunity to be contacted each time
    // we call for it
    get {
	  if (_remote == null) dbus_init();
	  return _remote;
    }
  }

  // Callbacks
  [CCode (instance_pos = -1)]
  public void on_top_hide(Gtk.Widget widget) {
    systraymenu_restore.set("sensitive",true);
  }

  [CCode (instance_pos = -1)]
  public void on_systray(Gtk.StatusIcon widget) {
    bool visible;
    top.get("visible", out visible);
    top.set("visible", !visible);
    systraymenu_restore.set("sensitive",visible);
  }

  [CCode (instance_pos = -1)]
  public void on_systray_menu(Gtk.StatusIcon widget, uint button, uint activateTime) {
    if (button!=3) {
      on_systray(widget);
      return;
    }
    systraymenu.popup(null, null, null, 0, activateTime);
  }

  [CCode (instance_pos = -1)]
  public void on_restore(Gtk.Widget widget) {
    top.set("visible", true);
    systraymenu_restore.set("sensitive",false);
  }

  [CCode (instance_pos = -1)]
  public void on_remove(Gtk.Widget widget) {
    if (remote == null) return;
    foreach (string share in get_selected_shares()) {
      try {
        remote.unregister_path(share);
      } catch (Error e) {
        log("Remote error deleting share '%s'\n".printf(share));
      }
    }
  }

  [CCode (instance_pos = -1)]
  public void on_add(Gtk.Widget widget) {
    if (remote == null) return;
    adddialog.set("visible", true);
  }

  [CCode (instance_pos = -1)]
  public void on_quit(Gtk.Widget widget) {
    quit();
  }

  [CCode (instance_pos = -1)]
  public void on_adddialogcancel(Gtk.Widget widget) {
    adddialog.set("visible", false);

    // Clear data for next use
    shareas.set_text("");
  }

  [CCode (instance_pos = -1)]
  public void on_adddialogok(Gtk.Widget widget) {
    string local_file = localdirectory.get_filename();
    string shared_as = shareas.get_text();

    if (shared_as != null) {
	  if (shared_as[0] != '/') shared_as = "/" + shared_as;
	  if (strcmp(shared_as.replace("/",""),"")==0) {
		error_dialog("Empty share name not allowed");
		return;
	  }
	  if (strcmp(shared_as,"/rss")==0) {
		error_dialog("Share name not allowed");
		return;
	  }
	}

    if (remote != null) {
      try {
        remote.register_path(local_file, shared_as);
      } catch (Error e) {
        log("Remote error sharing '%s' as '%s'\n".printf(local_file, shared_as));
      }
    }

    // Clear data for next use
    shareas.set_text("");

    adddialog.set("visible", false);
  }

  [CCode (instance_pos = -1)]
  public void on_about(Gtk.Widget widget) {
    aboutdialog.set("visible", true);
  }

  [CCode (instance_pos = -1)]
  public void on_aboutdialogclose(Gtk.Widget widget) {
    aboutdialog.set("visible", false);
  }

  [CCode (instance_pos = -1)]
  public void on_copy_invitation(Gtk.Widget widget) {
	clipboard.set_text(invitation, -1);
  }

  // Private methods
  private Gtk.MenuBar menushell_to_menubar(MenuShell menu) {
    Gtk.MenuBar menubar=new Gtk.MenuBar();
    weak List<Gtk.MenuItem> children=(List<Gtk.MenuItem>)menu.children;
    List<Gtk.MenuItem> childrencopy=new List<Gtk.MenuItem>();
    foreach (Gtk.MenuItem menuitem in children) {
      childrencopy.append(menuitem);
    }
    foreach (Gtk.MenuItem menuitem in childrencopy) {
      ((Gtk.Container)menuitem.parent).remove((Gtk.Widget)menuitem);
      menubar.append(menuitem);
    }
    return menubar;
  }

  private void error_dialog(string msg) {
	Gtk.MessageDialog d = new Gtk.MessageDialog(
												adddialog,
												Gtk.DialogFlags.DESTROY_WITH_PARENT,
												Gtk.MessageType.ERROR,
												Gtk.ButtonsType.CLOSE,
												"%s",
												msg);
	d.run();
	d.destroy();
  }

  private void log(string msg) {
	if (logtext!=null) {
	  logtext.get_buffer().insert_at_cursor(msg, (int)msg.length);
	} else {
	  stderr.printf("%s",msg);
	}
  }

  private void dbus_init() {
    try {
      var conn = DBus.Bus.get(DBus.BusType.SESSION);
	  _remote = conn.get_object (
								 "com.igalia.Meiga",
								 "/com/igalia/Meiga",
								 "com.igalia.Meiga");
    } catch (Error e) {
	  log("Error looking for DBUS server: %s\n".printf(e.message));
    }

	try {
	  // Test the connection
	  if (_remote != null) {
		public_url = _remote.get_public_url();
	  }
	} catch (Error e) {
	  log("Error looking for DBUS server: remote object not found\n");
	  _remote = null;
	}

	// Attach to remote signals
	if (_remote != null) {
	  _remote.ModelChanged += this.on_remote_model_changed;
	  _remote.LogChanged += this.on_remote_log_changed;
	}
  }

  public void on_remote_model_changed() {
	update_model();
	update_statusbar();
  }

  private void gui_init() {
    string[] path = UI_PATH.split(":",8);
	string iconfile = null;
	bool gui_loaded = false;

	builder = new Builder ();
    for (int i=0; path[i]!=null; i++) {
      string filename = path[i] + "/" + UI_FILENAME;
	  try {
		builder.add_from_file (filename);
		gui_loaded = true;
		iconfile = path[i] + "/" + "meiga-16x16.png";
		break;
	  } catch (Error e) {
		continue;
	  }
    }
    if (!gui_loaded) {
      log("Could not load UI file %s\n".printf(UI_FILENAME));
      quit();
    }

    builder.connect_signals(this);

    systraymenu = (Gtk.Menu)builder.get_object("systraymenu");
    systraymenu_restore = (Gtk.Action)builder.get_object("tray_restore");
    top = (Gtk.Window)builder.get_object("top");
    adddialog = (Gtk.Window)builder.get_object("adddialog");
    aboutdialog = (Gtk.Window)builder.get_object("aboutdialog");
    files = (Gtk.TreeView)builder.get_object("files");
	statusbar = (Gtk.Statusbar)builder.get_object("statusbar");
    localdirectory = (Gtk.FileChooserButton)builder.get_object("localdirectory");
    shareas = (Gtk.Entry)builder.get_object("shareas");
	logtext = (Gtk.TextView)builder.get_object("logtext");

    Gtk.VBox topvbox=(Gtk.VBox)builder.get_object("topvbox");

	try {
	  top.set_icon_from_file(iconfile);
	  adddialog.set_icon_from_file(iconfile);
	  aboutdialog.set_icon_from_file(iconfile);
	} catch (Error e) {
	  log("Icon file not found\n");
	}

    menu=menushell_to_menubar((Gtk.Menu)builder.get_object("menu"));
    menu.set("visible",true);
    topvbox.pack_start(menu,false,false,0);
	topvbox.reorder_child(menu,0);

    model = new Gtk.ListStore(2, typeof(string), typeof(string));
    files.set_model(model);
    files.insert_column_with_attributes (
										 -1, "Local file", new CellRendererText (),
										 "text", 0, null);
    files.insert_column_with_attributes (
										 -1, "Shared as", new CellRendererText (),
										 "text", 1, null);
    files.get_selection().set_mode(Gtk.SelectionMode.MULTIPLE);

	public_url = "";
	lastlog = 0;
	clipboard = Gtk.Clipboard.get(SELECTION_CLIPBOARD);

    update_model();
	update_log();

    systray = new Gtk.StatusIcon.from_file(iconfile);
    systray.activate += on_systray;
    systray.popup_menu += on_systray_menu;

    // App is finally shown
    systray.set("visible",true);
	on_restore(top);
  }

  private void update_model_from_string(Gtk.ListStore model, string string_model) {
    model.clear();
	preferred_share = null;
    if (string_model == null || string_model[0]=='\0') return;
    string[] rows = string_model.split("\n",128);
    for (int i=0; rows[i][0]!='\0'; i++) {
	  string[] cols = rows[i].split("\t",2);
	  string local_file = cols[1];
	  string shared_as = cols[0];
	  TreeIter iter;
	  model.append (out iter);
	  model.set(iter, 0, local_file, 1, shared_as);
	  if (i==0) {
		preferred_share = shared_as;
	  }
    }
  }

  private void update_model() {
    string_model = null;
    if (remote != null) {
      try {
		string_model = remote.get_paths_as_string();
      } catch (Error e) {
        log("Remote error getting paths\n");
      }
	}
    if (string_model == null) string_model = "";
    update_model_from_string(model, string_model);
  }

  private void update_log() {
	string new_log_lines = null;
    if (remote != null) {
      try {
		new_log_lines = remote.get_pending_log(lastlog);
      } catch (Error e) {
        log("Remote error getting log lines\n");
      }
	}
    if (new_log_lines == null) new_log_lines = "";

	// Count the number of new lines
	uint j = 0;
    for (uint i = 0; new_log_lines[i]!='\0'; i++) {
	  if (new_log_lines[i]=='\n') j++;
	}

	logtext.get_buffer().insert_at_cursor(new_log_lines, (int)new_log_lines.length);
	lastlog += j;
  }

  public void on_remote_log_changed() {
    update_log();
  }

  private void update_statusbar() {
	if (remote != null) {
      try {
		public_url = remote.get_public_url();
		if (public_url != null && public_url.length > 0 && preferred_share != null) {
		  invitation = public_url + preferred_share;
		} else {
		  invitation = "";
		}
		statusbar.pop(0);
		statusbar.push(0, invitation);
      } catch (Error e) {
        log("Remote error getting public url\n");
      }

	}
  }

  private List<string> get_selected_shares() {
    List<string> selection = new List<string>();
    foreach (weak Gtk.TreePath spath in files.get_selection().get_selected_rows(null)) {
      Gtk.TreeIter iter;
      if (model.get_iter(out iter, spath)) {
        string shared_as = null;
        model.get(iter, 1, out shared_as, -1);
        if (shared_as != null) selection.append(shared_as);
      }
    }
    return selection;
  }

  // Public methods
  public void init() {
    gui_init();
  }

  public void quit() {
    Gtk.main_quit();

    if (remote != null) {
      try {
        remote.shutdown();
      } catch (Error e) {
        log("Remote error shutting down server\n");
      }
	}
  }

  public static int main(string[] args) {
    Gui gui = new Gui();
    Gtk.init(ref args);
    gui.init();
    Gtk.main();
    return 0;
  }

}
