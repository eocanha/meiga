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
  
  private Gtk.ListStore model;
  private string string_model = "file1\tshare1\nfile2\tshare2\nfile3\tshare3\n";
  
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

  private void update_model_from_string(Gtk.ListStore model, string string_model) {
    string[] rows = string_model.split("\n",128);
    model.clear();
    for (int i=0; rows[i][0]!='\0'; i++) {
        string[] cols = rows[i].split("\t",2);
        TreeIter iter;
        model.append (out iter);
        model.set(iter, 0, cols[0], 1, cols[1]);
    }    
  }

  private void update_model() {
    // TODO: Contact with the server via DBUS and use a true string model
    update_model_from_string(model, string_model);
  }

  // Public methods
  public void gui_init() {
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
    
    Gtk.VBox topvbox=(Gtk.VBox)xml.get_widget("topvbox");
    Gtk.TreeView files = (Gtk.TreeView)xml.get_widget("files");
        
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

  public void quit() {
    Gtk.main_quit();
  }

  public static int main(string[] args) {
    Gui gui = new Gui();
    Gtk.init(ref args);
    gui.gui_init();
    Gtk.main();
    return 0;
  }

}