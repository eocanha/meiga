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
using Posix;

const string UI_PATH = "ui:"+Config.DATADIR+"/meiga/ui";

public class Gui : GLib.Object {

  // Private attributes
  private Gtk.MenuShell menu;
  private Gtk.Menu systraymenu;
  private Gtk.Window top;
  private Gtk.Window adddialog;
  private Gtk.Window aboutdialog;
  private Gtk.StatusIcon systray;
  private Gtk.MenuItem systraymenu_restore;
  private Gtk.VBox topvbox;
  private Gtk.TreeView files;
  private Gtk.ComboBox redirection_type;
  private Gtk.Entry ssh_host;
  private Gtk.Entry ssh_port;
  private Gtk.Entry ssh_user;
  private Gtk.Entry ssh_password;
  private Gtk.Button redirection_apply;
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
  private uint pid;
  private string display;

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
        log(_("Remote error deleting share '%s'\n").printf(share));
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
  public void on_redirection_apply(Gtk.Widget widget) {
	if (remote == null) return;
	try {
	  remote.set_ssh_host(ssh_host.get_text());
	  remote.set_ssh_port(ssh_port.get_text());
	  remote.set_ssh_user(ssh_user.get_text());
	  remote.set_ssh_password(ssh_password.get_text());
	  remote.set_redirection_type(redirection_type.get_active());
	} catch (Error e) {
	  log(_("Remote error applying redirection options\n"));
	}
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
		error_dialog(_("Empty share name not allowed"));
		return;
	  }
	  if (strcmp(shared_as,"/rss")==0) {
		error_dialog(_("Share name not allowed"));
		return;
	  }
	}

    if (remote != null) {
      try {
        remote.register_path(local_file, shared_as);
      } catch (Error e) {
        log(_("Remote error sharing '%s' as '%s'\n").printf(local_file, shared_as));
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
	  Gtk.TextBuffer b = logtext.get_buffer();
	  Gtk.TextIter end;
	  b.get_end_iter(out end);
	  logtext.get_buffer().insert(end,msg, -1);
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
	  log(_("Error looking for DBUS server: %s\n").printf(e.message));
    }

	try {
	  // Test the connection
	  if (_remote != null) {
		_remote.register_gui(pid, display);
	  }
	} catch (Error e) {
	  log(_("Error looking for DBUS server: remote object not found\n"));
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

  private void nautilus_init() {
	// If there's no link to the Nautilus menu entry in the
	// user's directory, create it
	string menudir = Environment.get_home_dir() + "/.gnome2/nautilus-scripts/";
	string menulink = menudir + _("Share on Meiga...");
	string menufile = Config.DATADIR + "/nautilus-scripts/" + "share-on-meiga";
	if (!FileUtils.test(menulink,
						FileTest.EXISTS)) {
	  log(_("Creating Nautilus context menu for Meiga %s --> %s\n")
		  .printf(menulink,menufile));
	  DirUtils.create_with_parents(menudir,0700);
	  FileUtils.symlink(menufile, menulink);
	}
  }

  private void gui_init() {
    string[] path = UI_PATH.split(":",8);
	string iconfile = null;

    for (int i=0; path[i]!=null; i++) {
	  iconfile = path[i] + "/" + "meiga-16x16.png";
	  if (FileUtils.test(iconfile,FileTest.IS_REGULAR)) break;
    }

	create_top_menu();
	create_systray_menu();
    create_top();
	create_adddialog();
	create_aboutdialog();

	try {
	  top.set_icon_from_file(iconfile);
	  adddialog.set_icon_from_file(iconfile);
	  aboutdialog.set_icon_from_file(iconfile);
	} catch (Error e) {
	  log(_("Icon file not found\n"));
	}

    menu=menushell_to_menubar(menu);
    menu.set("visible",true);
    topvbox.pack_start(menu,false,false,0);
	topvbox.reorder_child(menu,0);

	pid = (uint)Posix.getpid();
	display = Environment.get_variable("DISPLAY");

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
	// Setting REDIRECTION_STATUS_PENDING ensures that the options will
	// be shaded unless the server confirms its status
	int int_redirection_status = 1;
	int int_redirection_type = 0;
	bool enable_redirection_options;

    string_model = null;
    if (remote != null) {
      try {
		string_model = remote.get_paths_as_string();
      } catch (Error e) {
        log(_("Remote error getting paths\n"));
      }
      try {
		int_redirection_type = remote.get_redirection_type();
		int_redirection_status = remote.get_redirection_status();
      } catch (Error e) {
        log(_("Remote error getting redirection options\n"));
      }
	}
    if (string_model == null) string_model = "";
    update_model_from_string(model, string_model);

	redirection_type.set_active(int_redirection_type);

	// Disable redirection settings when redirection process is pending
	enable_redirection_options = (int_redirection_status != 1);
	redirection_type.set_sensitive(enable_redirection_options);
	ssh_host.set_sensitive(enable_redirection_options);
	ssh_port.set_sensitive(enable_redirection_options);
	ssh_user.set_sensitive(enable_redirection_options);
	ssh_password.set_sensitive(enable_redirection_options);
	redirection_apply.set_sensitive(enable_redirection_options);
  }

  private void update_log() {
	string new_log_lines = null;
    if (remote != null) {
      try {
		new_log_lines = remote.get_pending_log(lastlog);
      } catch (Error e) {
        log(_("Remote error getting log lines\n"));
      }
	}
    if (new_log_lines == null) new_log_lines = "";

	// Count the number of new lines
	uint j = 0;
    for (uint i = 0; new_log_lines[i]!='\0'; i++) {
	  if (new_log_lines[i]=='\n') j++;
	}

	log(new_log_lines);
	lastlog += j;
  }

  public void on_remote_log_changed() {
    update_log();
  }

  private void update_statusbar() {
	if (remote != null) {
      try {
		int status = remote.get_redirection_status();
		string string_status;
		public_url = remote.get_public_url();
		if (public_url != null && public_url.length > 0 && preferred_share != null) {
		  invitation = public_url + preferred_share;
		  string_status = " - ";
		} else {
		  invitation = "";
		  string_status = "";
		}

		string_status += remote.get_requests_stats();
		string_status += " - ";

		switch (status) {
		case 0: string_status += _("Direct connection"); break;
		case 1: string_status += _("Performing redirection"); break;
		case 2: string_status += _("Redirection performed"); break;
		case 3: string_status += _("Redirection error"); break;
		}
		statusbar.pop(0);
		statusbar.push(0, invitation+string_status);
      } catch (Error e) {
        log(_("Remote error getting public url\n"));
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
	nautilus_init();
  }

  public void quit() {
    Gtk.main_quit();

    if (remote != null) {
      try {
        remote.shutdown();
      } catch (Error e) {
        log(_("Remote error shutting down server\n"));
      }
	}
  }

  private void create_top_menu() {
	menu = new Gtk.Menu();
	{
	  Gtk.MenuItem filemenu = new Gtk.MenuItem.with_mnemonic(_("_File"));
	  {
		Gtk.Menu filemenumenu = new Gtk.Menu();
		{
		  Gtk.ImageMenuItem quit = new Gtk.ImageMenuItem.from_stock("gtk-quit", null);
		  quit.show();
		  filemenumenu.add(quit);
		  quit.activate += on_quit;
		}
		filemenumenu.show();
		filemenu.submenu = filemenumenu;
	  }
	  filemenu.show();
	  menu.add(filemenu);

	  Gtk.MenuItem sharemenu = new Gtk.MenuItem.with_mnemonic(_("_Share"));
	  {
		Gtk.Menu sharemenumenu = new Gtk.Menu();
		{
		  Gtk.ImageMenuItem add = new Gtk.ImageMenuItem.from_stock("gtk-add", null);
		  add.show();
		  sharemenumenu.add(add);
		  add.activate += on_add;

		  Gtk.ImageMenuItem remove = new Gtk.ImageMenuItem.from_stock("gtk-remove", null);
		  remove.show();
		  sharemenumenu.add(remove);
		  remove.activate += on_remove;

		  Gtk.ImageMenuItem copy_invitation = new Gtk.ImageMenuItem.with_mnemonic("_Copy invitation");
		  copy_invitation.image = new Gtk.Image.from_stock("gtk-copy", Gtk.IconSize.MENU);
		  copy_invitation.show();
		  sharemenumenu.add(copy_invitation);
		  copy_invitation.activate += on_copy_invitation;
		}
		sharemenumenu.show();
		sharemenu.submenu = sharemenumenu;
	  }
	  sharemenu.show();
	  menu.add(sharemenu);

	  Gtk.MenuItem helpmenu = new Gtk.MenuItem.with_mnemonic(_("_Help"));
	  {
		Gtk.Menu helpmenumenu = new Gtk.Menu();
		{
		  Gtk.ImageMenuItem about = new Gtk.ImageMenuItem.from_stock("gtk-about", null);
		  about.show();
		  helpmenumenu.add(about);
		  about.activate += on_about;
		}
		helpmenumenu.show();
		helpmenu.submenu = helpmenumenu;
	  }
	  helpmenu.show();
	  menu.add(helpmenu);
	}
  }

  private void create_systray_menu() {
	systraymenu = new Gtk.Menu();
	{
	  systraymenu_restore = new Gtk.MenuItem.with_mnemonic("_Restore");
	  systraymenu_restore.show();
	  systraymenu.add(systraymenu_restore);
	  systraymenu_restore.activate += on_restore;

	  Gtk.SeparatorMenuItem sep = new Gtk.SeparatorMenuItem();
	  sep.show();
	  systraymenu.add(sep);

	  Gtk.ImageMenuItem copy_invitation = new Gtk.ImageMenuItem.with_mnemonic("_Copy invitation");
	  copy_invitation.image = new Gtk.Image.from_stock("gtk-copy", Gtk.IconSize.MENU);
	  copy_invitation.show();
	  systraymenu.add(copy_invitation);
	  copy_invitation.activate += on_copy_invitation;

	  Gtk.ImageMenuItem quit = new Gtk.ImageMenuItem.from_stock("gtk-quit", null);
	  quit.show();
	  systraymenu.add(quit);
	  quit.activate += on_quit;
	}
  }

  private void create_top() {
	top = new Gtk.Window(Gtk.WindowType.TOPLEVEL);
	top.title = _("Meiga");
	top.default_height = 400;
	top.default_width = 350;

	{
	  topvbox = new Gtk.VBox(false, 0);
	  {
		Gtk.HandleBox hb = new Gtk.HandleBox();
		{
		  Gtk.Toolbar tb = new Gtk.Toolbar();
		  {
			Gtk.ToolButton tadd = new Gtk.ToolButton.from_stock("gtk-add");
			tb.insert(tadd, -1);
			tadd.show();
			tadd.clicked += on_add;

			Gtk.ToolButton tremove = new Gtk.ToolButton.from_stock("gtk-remove");
			tb.insert(tremove, -1);
			tremove.show();
			tremove.clicked += on_remove;

			Gtk.ToolButton tcopy_invitation = new Gtk.ToolButton.from_stock("gtk-copy");
			tb.insert(tcopy_invitation, -1);
			tcopy_invitation.show();
			tcopy_invitation.clicked += on_copy_invitation;
		  }
		  hb.add(tb);
		  tb.show();
		}
		Gtk.Notebook nb = new Gtk.Notebook();
		{
		  Gtk.ScrolledWindow sw1 = new Gtk.ScrolledWindow(null, null);
		  {
			files = new Gtk.TreeView();
			sw1.add(files);
			files.show();

			model = new Gtk.ListStore(2, typeof(string), typeof(string));
			files.set_model(model);
			files.insert_column_with_attributes (
												 -1, _("Local file"), new CellRendererText (),
												 "text", 0, null);
			files.insert_column_with_attributes (
												 -1, _("Shared as"), new CellRendererText (),
												 "text", 1, null);
			files.get_selection().set_mode(Gtk.SelectionMode.MULTIPLE);
		  }
		  sw1.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		  sw1.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		  sw1.shadow_type = Gtk.ShadowType.IN;
		  nb.append_page(sw1, new Gtk.Label(_("Shares")));
		  sw1.show();

		  Gtk.ScrolledWindow sw2 = new Gtk.ScrolledWindow(null, null);
		  {
			logtext = new Gtk.TextView();
			logtext.editable = false;
			logtext.left_margin = 5;
			logtext.right_margin = 5;
			logtext.cursor_visible = false;
			sw2.add(logtext);
			logtext.show();
		  }
		  sw2.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		  sw2.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		  sw2.shadow_type = Gtk.ShadowType.IN;
		  nb.append_page(sw2, new Gtk.Label(_("Log")));
		  sw2.show();

		  Gtk.ScrolledWindow sw3 = new Gtk.ScrolledWindow(null, null);
		  {
			Gtk.VBox vb = new Gtk.VBox(false, 0);
			{
			  Gtk.HBox hb2 = new Gtk.HBox(false, 0);
			  {
				Gtk.Label l = new Gtk.Label(_("Port redirection scheme"));
				hb2.pack_start(l, false, false, 5);
				l.show();

				redirection_type = new Gtk.ComboBox();
				hb2.pack_start(redirection_type, true, true, 5);
				redirection_type.show();

				Gtk.ListStore redirection_type_model = new Gtk.ListStore(1, typeof(string));
				Gtk.TreeIter redirection_type_model_iter;
				Gtk.CellRenderer redirection_type_model_cell_renderer;
				redirection_type.set_model(redirection_type_model);
				redirection_type_model.append(out redirection_type_model_iter);
				redirection_type_model.set(redirection_type_model_iter, 0, _("None"), -1);
				redirection_type_model.append(out redirection_type_model_iter);
				redirection_type_model.set(redirection_type_model_iter, 0, _("UPnP"), -1);
				redirection_type_model.append(out redirection_type_model_iter);
				redirection_type_model.set(redirection_type_model_iter, 0, _("SSH"), -1);
				redirection_type_model.append(out redirection_type_model_iter);
				redirection_type_model.set(redirection_type_model_iter, 0, _("FON"), -1);
				redirection_type_model_cell_renderer = new Gtk.CellRendererText();
				redirection_type.pack_start(redirection_type_model_cell_renderer, true);
				redirection_type.set_attributes(redirection_type_model_cell_renderer,
												"text",
												0);
			  }
			  vb.pack_start(hb2, false, false, 5);
			  hb2.show();

			  Gtk.Frame f = new Gtk.Frame(_("<b>SSH options</b>"));
			  ((Gtk.Label)(f.label_widget)).use_markup = true;
			  {
				Gtk.Alignment ga = new Gtk.Alignment((float)0.5, (float)0.5, (float)1.0, (float)1.0);
				{
				  Gtk.Table t = new Gtk.Table(4, 2, false);
				  {
					Gtk.Label lh = new Gtk.Label(_("Host"));
					lh.xalign = (float)0.0;
					t.attach(lh, 0, 1, 0, 1,
							 Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					lh.show();

					ssh_host = new Gtk.Entry();
					t.attach(ssh_host, 1, 2, 0, 1,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					ssh_host.show();

					Gtk.Label lp = new Gtk.Label(_("Port"));
					lp.xalign = (float)0.0;
					t.attach(lp, 0, 1, 1, 2,
							 Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					lp.show();

					ssh_port = new Gtk.Entry();
					t.attach(ssh_port, 1, 2, 1, 2,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					ssh_port.show();

					Gtk.Label lu = new Gtk.Label(_("User"));
					lu.xalign = (float)0.0;
					t.attach(lu, 0, 1, 2, 3,
							 Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					lu.show();

					ssh_user = new Gtk.Entry();
					t.attach(ssh_user, 1, 2, 2, 3,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					ssh_user.show();

					Gtk.Label lpw = new Gtk.Label(_("Password"));
					lpw.xalign = (float)0.0;
					t.attach(lpw, 0, 1, 3, 4,
							 Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					lpw.show();

					ssh_password = new Gtk.Entry();
					t.attach(ssh_password, 1, 2, 3, 4,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
							 3, 3);
					ssh_password.visibility = false;
					ssh_password.invisible_char = '*';
					ssh_password.show();
				  }
				  t.set_col_spacings(5);
				  t.set_row_spacings(5);
				  ga.add(t);
				  t.show();
				}
				f.add(ga);
				ga.show();
			  }
			  f.shadow_type = Gtk.ShadowType.NONE;
			  vb.pack_start(f, false, false, 5);
			  f.show();

			  redirection_apply = new Gtk.Button.from_stock("gtk-apply");
			  vb.pack_start(redirection_apply, false, false, 5);
			  redirection_apply.show();

			  redirection_apply.clicked += on_redirection_apply;
			}
			sw3.add_with_viewport(vb);
			vb.show();
		  }
		  sw3.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		  sw3.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		  sw3.shadow_type = Gtk.ShadowType.NONE;
		  nb.append_page(sw3, new Gtk.Label(_("Options")));
		  sw3.show();
		}
		statusbar = new Gtk.Statusbar();

		topvbox.pack_start(hb, false, false, 0);
		hb.show();

		nb.tab_pos = Gtk.PositionType.BOTTOM;
		topvbox.pack_start(nb, true, true, 0);
		nb.show();

		topvbox.pack_start(statusbar, false, false, 0);
		statusbar.show();
	  }
	  top.add(topvbox);
	  topvbox.show();
	}

	top.hide += on_top_hide;
	top.delete_event += top.hide_on_delete;
	top.show();
  }

  private void create_adddialog() {
	adddialog = new Gtk.Dialog();
	adddialog.title = _("Add path");
	adddialog.modal = true;
	adddialog.type_hint = Gdk.WindowTypeHint.DIALOG;
	adddialog.position = Gtk.WindowPosition.CENTER;
	{
	  Gtk.Container content_area = (Gtk.Container)((Gtk.Dialog)adddialog).get_content_area();

	  Gtk.Alignment ga = new Gtk.Alignment((float)0.5, (float)0.5, (float)1.0, (float)1.0);
	  {
		Gtk.Table t = new Gtk.Table(2, 2, false);
		{
		  Gtk.Label ld = new Gtk.Label(_("Local directory"));
		  ld.xalign = (float)0.0;
		  t.attach(ld, 0, 1, 0, 1,
				   Gtk.AttachOptions.FILL,
				   Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
				   3, 3);
		  ld.show();

		  localdirectory = new Gtk.FileChooserButton(_("Select a folder to share"),
													 Gtk.FileChooserAction.SELECT_FOLDER);
		  t.attach(localdirectory, 1, 2, 0, 1,
				   Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
				   Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
				   3, 3);
		  localdirectory.show();

		  Gtk.Label ls = new Gtk.Label(_("Share as"));
		  ls.xalign = (float)0.0;
		  t.attach(ls, 0, 1, 1, 2,
				   Gtk.AttachOptions.FILL,
				   Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
				   3, 3);
		  ls.show();

		  shareas = new Gtk.Entry();
		  t.attach(shareas, 1, 2, 1, 2,
				   Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
				   Gtk.AttachOptions.EXPAND | Gtk.AttachOptions.FILL,
				   3, 3);
		  shareas.show();
		}
		t.set_col_spacings(5);
		t.set_row_spacings(5);
		ga.add(t);
		t.show();
	  }
	  content_area.add(ga);
	  ga.show();

	  Gtk.Container action_area = (Gtk.Container)((Gtk.Dialog)adddialog).get_action_area();
	  Gtk.Button c = new Gtk.Button.from_stock("gtk-cancel");
	  action_area.add(c);
	  c.show();
	  c.clicked += on_adddialogcancel;

	  Gtk.Button a = new Gtk.Button.from_stock("gtk-ok");
	  action_area.add(a);
	  a.show();
	  a.clicked += on_adddialogok;
	}

	adddialog.hide += on_adddialogcancel;
	adddialog.delete_event += adddialog.hide_on_delete;
  }

  private void create_aboutdialog() {
	Gtk.AboutDialog a = new Gtk.AboutDialog();
	aboutdialog = a;
	a.program_name = _("Meiga");
	a.version = Config.VERSION;
	a.copyright = "(C) 2009 Igalia, S.L.";
	a.license = _("This program comes with ABSOLUTELY NO WARRANTY.\n") +
	            _("Licensed under GNU GPL 2.0. This is free software, and you are welcome to ") +
				_("redistribute it under certain conditions.\n") +
				  "\n" +
				_("For more information, see:\n") +
				  "\n" +
				  "http://www.gnu.org/licenses/old-licenses/gpl-2.0.html\n" +
				  "\n" +
				_("Xunta de Galicia partially funded this project using ") +
				_("the European Regional Development Fund (ERDF)\n");
	a.website = "http://meiga.igalia.com";
	a.modal = true;
	a.type_hint = Gdk.WindowTypeHint.DIALOG;
	a.position = Gtk.WindowPosition.CENTER;
	a.default_height = 300;
	a.default_width = 300;
	List blist = ((Gtk.Container)a.get_action_area()).get_children();
	Gtk.Button b = (Gtk.Button)(blist.last().data);
	b.clicked += on_aboutdialogclose;
	a.hide += on_aboutdialogclose;
	a.delete_event += a.hide_on_delete;
  }

  public static int main(string[] args) {
	Intl.setlocale(LocaleCategory.ALL,"");
	Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
	Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain(Config.GETTEXT_PACKAGE);

    Gui gui = new Gui();
    Gtk.init(ref args);
    gui.init();
    Gtk.main();
    return 0;
  }

}
