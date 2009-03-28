using GLib;
using Gtk;
using Glade;

const string GLADE_FILENAME = "gui.glade";
const string GLADE_PATH = "glade:/usr/share/fromgnometotheworld/glade";

public class Gui : GLib.Object {

  // Private attributes
  private Glade.XML xml;
  private Gtk.MenuShell menu;
  private Gtk.Menu systraymenu;
  private Gtk.Window top;
  private Gtk.Window adddialog;
  private Gtk.Window aboutdialog;
  private Gtk.StatusIcon systray;
  private Gtk.MenuItem systraymenu_restore;
  private Gtk.TreeView files;
  
  private Gtk.ListStore model;
  private string string_model;
  
  private dynamic DBus.Object bus;
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
  public void on_refresh(Gtk.Widget widget) {
    update_model();
  }
  
  [CCode (instance_pos = -1)]
  public void on_remove(Gtk.Widget widget) {
    if (remote == null) return;
    foreach (string share in get_selected_shares()) {
      try {
        remote.unregister_path(share);
      } catch (Error e) {
        stderr.printf("Remote error deleting share '%s'\n", share);
      }
    }
    update_model();
  }
  
  [CCode (instance_pos = -1)]
  public void on_quit(Gtk.Widget widget) {
    quit();
  }
  
  // Private methods
  [CCode (instance_pos = -1)]
  private void connect_signals(string handler_name, GLib.Object object, string signal_name, string? signal_data, GLib.Object? connect_object, bool after) {
    Module module = Module.open(null, ModuleFlags.BIND_LAZY);
    void* sym;
        
    if(!module.symbol(handler_name, out sym)) {
      stdout.printf("Symbol not found: %s\n",handler_name);
    } else {
      GLib.Signal.connect(object, signal_name, (GLib.Callback) sym, this);
    }
  }

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

  private void dbus_init() {
    try {
      var conn = DBus.Bus.get(DBus.BusType.SESSION);
      bus = conn.get_object(
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus");
      uint request_name_result = bus.request_name (
        "org.gnome.FromGnomeToTheWorld", (uint) 0);
      if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
        stderr.printf("Remote DBUS service not found\n");
        // Avoid being pointed as the owners because we aren't
        bus.release_name("org.gnome.FromGnomeToTheWorld");
      } else {
        _remote = conn.get_object (
          "org.gnome.FromGnomeToTheWorld",
          "/org/gnome/FromGnomeToTheWorld",
          "org.gnome.FromGnomeToTheWorld");
      }
    } catch (Error e) {
     stderr.printf("Error registering DBUS server: %s\n",e.message);
    }
  }

  private void gui_init() {
    string[] path = GLADE_PATH.split(":",8);
    for (int i=0; path[i]!=null && xml==null; i++) {
      string filename = path[i] + "/" + GLADE_FILENAME;
      xml = new Glade.XML(filename, null, null);
    }
    if (xml==null) {
      stderr.printf("Glade file not found\n");
      quit();
    }
    xml.signal_autoconnect_full(connect_signals);
    
    systraymenu = (Gtk.Menu)xml.get_widget("systraymenu");
    systraymenu_restore = (Gtk.MenuItem)xml.get_widget("restore");
    top = (Gtk.Window)xml.get_widget("top");
    adddialog = (Gtk.Window)xml.get_widget("adddialog");
    aboutdialog = (Gtk.Window)xml.get_widget("aboutdialog");
    files = (Gtk.TreeView)xml.get_widget("files");
    
    Gtk.VBox topvbox=(Gtk.VBox)xml.get_widget("topvbox");
        
    menu=menushell_to_menubar((Gtk.Menu)xml.get_widget("menu"));
    menu.set("visible",true);
    topvbox.pack_start(menu,false,false,0);
        
    model = new Gtk.ListStore(2, typeof(string), typeof(string));
    files.set_model(model);
    files.insert_column_with_attributes (-1, "Local file", new CellRendererText (), "text", 0, null);
    files.insert_column_with_attributes (-1, "Shared as", new CellRendererText (), "text", 1, null);
    files.get_selection().set_mode(Gtk.SelectionMode.MULTIPLE);

    // TODO: Put more initializations here
    update_model();

    systray = new Gtk.StatusIcon.from_icon_name("stock_shared-by-me");
    systray.activate += on_systray;
    systray.popup_menu += on_systray_menu;
        
    // App is finally shown
    systray.set("visible",true);
  }
  
  private void update_model_from_string(Gtk.ListStore model, string string_model) {
    model.clear();
    if (string_model == null || string_model[0]=='\0') return;
    string[] rows = string_model.split("\n",128);
    for (int i=0; rows[i][0]!='\0'; i++) {
        string[] cols = rows[i].split("\t",2);
        string local_file = cols[1];
        string shared_as = cols[0];
        TreeIter iter;
        model.append (out iter);
        model.set(iter, 0, local_file, 1, shared_as);
    }    
  }

  private void update_model() {
    string_model = null;
    if (remote != null) string_model = remote.get_paths_as_string();
    if (string_model == null) string_model = "";
    update_model_from_string(model, string_model);
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
  }

  public static int main(string[] args) {
    Gui gui = new Gui();
    Gtk.init(ref args);
    gui.init();
    Gtk.main();
    return 0;
  }

}