using GLib;

[DBus (name = "org.gnome.FromGnomeToTheWorld", signals="has_changed")]
public class FromGnomeToTheWorld : GLib.Object {
 public Myserver server;
 public signal void has_changed();
 
 public FromGnomeToTheWorld() {
 }

 public void register_path(string real_path, string logical_path) {
  server.register_path(real_path,logical_path);
  has_changed();
 }
  
 public void unregister_path(string logical_path) {
  server.unregister_path(logical_path);
  has_changed();  
 }
 
 public HashTable<string,string> get_paths() {
  return server.get_paths();
 }

 public string get_paths_as_string() {
  HashTable<string,string> t=server.get_paths();
  string result="";
  foreach (string k in t.get_keys()) {
   string v=t.lookup(k);
   result+=k+"\t"+v+"\n";
  }
  return result;
 }

 public void shutdown() {
  server.shutdown();
 }

}