using GLib;

[DBus (name = "com.igalia.Meiga", signals="has_changed")]
public class Meiga : GLib.Object {
  private MeigaServer server;
  public signal void has_changed();

  public Meiga(MeigaServer server) {
	this.server = server;
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

  public string get_public_url() {
	return server.get_public_url();
  }

  public void shutdown() {
	server.shutdown();
  }

}