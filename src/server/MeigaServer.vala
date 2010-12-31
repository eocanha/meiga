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
using Soup;
using Gtk;
using Config;
using Posix;

public class MeigaServer : GLib.Object {
  const string MIME_TYPES_FILE="/etc/mime.types";

  private Soup.Server server;
  private GLib.HashTable<string,string> path_mapping;
  private GLib.HashTable<string,string> mimetypes;
  private Meiga exposed;
  private Net net;
  private uint pending_requests;
  private uint total_requests;
  private GLib.KeyFile settings;

  public Log logger { public get; private set; default=null; }
  public uint gui_pid { public get; private set; default=0; }
  public string display { public get; private set; default=null; }
  public uint _port = 8001;
  public uint port {
	public get { return _port; }
	public set { _port = value; }
  }
  public bool ssl { public get; public set; default=false; }
  public string auth_user { public get; public set; default=""; }
  public string auth_md5passwd { public get; public set; default=""; }

  public signal void model_changed();

  public MeigaServer() {
  }

  private void log(string msg) {
	if (logger!=null) logger.log(msg);
  }

  public void initialize() {
	logger = new Log();

	pending_requests=0;
	total_requests=0;

	initialize_mimetypes();
	path_mapping=new GLib.HashTable<string,string>(GLib.str_hash,GLib.str_equal);
	initialize_dbus();

	notify["port"] += (s, p) => {
	  reinitialize();
	  save_settings();
	  model_changed();
	};

	notify["ssl"] += (s, p) => {
	  reinitialize();
	  save_settings();
	  model_changed();
	};

	notify["auth_user"] += (s, p) => {
	  reinitialize();
	  save_settings();
	  model_changed();
	};

	notify["auth_md5passwd"] += (s, p) => {
	  reinitialize();
	  save_settings();
	  model_changed();
	};
  }

  private void enforce_meiga_ssl_cert() {
	string txtout;
	string txterr;
	int result;

	if (!(FileUtils.test(Environment.get_home_dir()+"/.meiga/ssl/meiga.pem", FileTest.EXISTS)
		  && FileUtils.test(Environment.get_home_dir()+"/.meiga/ssl/meiga.key",	FileTest.EXISTS))) {
	  try {
		GLib.Process.spawn_command_line_sync(Config.BINDIR+"/make-meiga-ssl-cert",
											 out txtout,
											 out txterr,
											 out result);
		if (result != 0) {
		  log(_("Error creating SSL certificate"));
		}
	  } catch (GLib.SpawnError e) {
		log(_("Error spawning SSL certificate creation process"));
	  }
	}
  }

  private void reinitialize() {
	if (server!=null) {
	  foreach (string logical_path in path_mapping.get_keys()) {
		server.remove_handler(logical_path);
	  }
	  server.remove_handler("/rss");
	  server.remove_handler("/");
	  server.quit();
	  server = null;
	}

	int tries = 100;
	while (server==null && tries>0) {
	  if (tries==1) _port = Soup.ADDRESS_ANY_PORT;
	  if (ssl) {
		enforce_meiga_ssl_cert();
		server=new Server(Soup.SERVER_PORT, port,
						  Soup.SERVER_SSL_CERT_FILE, Environment.get_home_dir()+"/.meiga/ssl/meiga.pem",
						  Soup.SERVER_SSL_KEY_FILE, Environment.get_home_dir()+"/.meiga/ssl/meiga.key");
	  } else {
		server=new Server(Soup.SERVER_PORT, port);
	  }
	  tries--;
	}
	_port = server.get_port();

	if (auth_user!="" && auth_md5passwd!="") {
	  Soup.AuthDomainBasic auth = new Soup.AuthDomainBasic(
		Soup.AUTH_DOMAIN_REALM, "Meiga",
		Soup.AUTH_DOMAIN_BASIC_AUTH_CALLBACK, on_auth_callback,
		Soup.AUTH_DOMAIN_BASIC_AUTH_DATA, this,
		Soup.AUTH_DOMAIN_ADD_PATH, "/");
	  server.add_auth_domain(auth);
	}

	server.add_handler("/",serve_file_callback_default);
	server.add_handler("/rss",serve_rss_callback);

	foreach (string logical_path in path_mapping.get_keys()) {
	  server.add_handler(logical_path,serve_file_callback);
	}

	server.run_async();
	if (net!=null) {
	  net.protocol = (ssl?"https":"http");
	  net.port = port;
	}
  }

  public void initialize_net() {
	net = new Net();
	net.logger = logger;
	net.protocol = (ssl?"https":"http");
	net.port = port;
	net.display = display;
	net.redirection_type = Net.REDIRECTION_TYPE_NONE;
	net.notify["url"] += (s, p) => {
	  log(_("External URL: %s").printf(get_public_url()));
	  model_changed();
	};
	net.notify["redirection-type"] += (s, p) => {
	  model_changed();
	};
	net.notify["redirection-status"] += (s, p) => {
	  model_changed();
	};
  }

  private void initialize_mimetypes() {
	mimetypes=new GLib.HashTable<string,string>(GLib.str_hash,GLib.str_equal);
	try {
	  FileStream f=FileStream.open(MIME_TYPES_FILE,"r");
	  char[] buffline=new char[128];
	  string line=null;
	  if (f==null) throw new FileError.FAILED("opening");
	  while (!f.eof()) {
		f.gets(buffline);
		line=(string)buffline;
		if (line==null || f.eof()) continue;
		string[] buf=line.split_set(" \t",2);
		string mime=buf[0].strip();
		if (buf[1]==null) continue;
		string[] extension=buf[1].strip().split_set(" \t");

		for (int i=0;extension[i]!=null;i++) {
		  mimetypes.insert(extension[i].strip(),mime);
		}
	  }
	} catch (FileError e) {
	  log(_("Error opening file %s").printf(MIME_TYPES_FILE));
	}
  }

  private void initialize_dbus() {
	try {
	  this.exposed=new Meiga(this);

	  var conn = DBus.Bus.get(DBus.BusType.SESSION);
	  dynamic DBus.Object bus = conn.get_object(
												"org.freedesktop.DBus",
												"/org/freedesktop/DBus",
												"org.freedesktop.DBus");
	  uint request_name_result = bus.request_name ("com.igalia.Meiga", (uint) 0);
	  if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
		log(_("Registering DBUS service"));
		conn.register_object ("/com/igalia/Meiga", (GLib.Object)this.exposed);
	  } else {
		log(_("Not registering DBUS service: not primary owner"));
	  }
	} catch (Error e) {
	  log(_("Error registering DBUS server: %s").printf(e.message));
	}
  }

  private void initialize_settings() {
	string filename = Environment.get_home_dir()+"/.meiga/meiga.ini";
	settings = new KeyFile();
	try {
	  if (!FileUtils.test(filename, FileTest.EXISTS)) throw new Error(Quark.from_string(""),1,"");
	  settings.load_from_file(filename, KeyFileFlags.KEEP_COMMENTS & KeyFileFlags.KEEP_TRANSLATIONS);
	} catch (Error e) {	}

	try {
	  string[] stpaths = settings.get_string_list("meiga", "paths");
	  for (int i=1; i<stpaths.length; i+=2) {
		string logical_path = stpaths[i-1];
		string real_path = stpaths[i];
		path_mapping.insert(logical_path,real_path);
	  }
	} catch (KeyFileError e) { }

	try {
	  uint stport = (uint)settings.get_string("meiga", "port").to_long();
	  _port = stport;
	} catch (KeyFileError e) { }

	try {
	  bool stssl = settings.get_boolean("meiga", "ssl");
	  ssl = stssl;
	} catch (KeyFileError e) { }

	try {
	  string stauth_user = settings.get_string("meiga", "auth_user");
	  auth_user = stauth_user;
	} catch (KeyFileError e) { }

	try {
	  string stauth_md5passwd = settings.get_string("meiga", "auth_md5passwd");
	  auth_md5passwd = stauth_md5passwd;
	} catch (KeyFileError e) { }

	save_settings();
  }

  private void save_settings() {
	string filename = Environment.get_home_dir()+"/.meiga/meiga.ini";

	string[] stpaths = {};
	List<weak string> keys=path_mapping.get_keys().copy();
	keys.sort(GLib.strcmp);
	foreach (weak string k in keys) {
	  string v=path_mapping.lookup(k);
	  stpaths += k;
	  stpaths += v;
	}
	settings.set_string_list("meiga", "paths", stpaths);
    settings.set_string("meiga", "port", "%u".printf(_port));
	settings.set_boolean("meiga", "ssl", ssl);
    settings.set_string("meiga", "auth_user", auth_user);
    settings.set_string("meiga", "auth_md5passwd", auth_md5passwd);

	try {
	  FileUtils.set_contents(filename, settings.to_data());
	} catch (FileError e) { }
  }

  public string get_public_url() {
	return net.url;
  }

  public void shutdown() {
	if (server!=null) {
	  foreach (string logical_path in path_mapping.get_keys()) {
		server.remove_handler(logical_path);
	  }
	  server.remove_handler("/rss");
	  server.remove_handler("/");
	  server.quit();
	}
	net.redirection_type = Net.REDIRECTION_TYPE_NONE;
	Idle.add_full(Priority.LOW, () => { Gtk.main_quit(); return false; });
  }

  public void register_gui(uint gui_pid, string display) {
	this.gui_pid = gui_pid;
	this.display = display;
	if (this.net == null) {
	  initialize_settings();
	  reinitialize();
	  initialize_net();
	}
	model_changed();
  }

  public void register_path(string real_path, string logical_path) {
	// For security reasons, don't allow path registering if
	// there's no GUI to monitor it
	if (gui_pid == 0) {
	  log(_("Attempted to register path without GUI started. Ignoring."));
	  return;
	}

	if (path_mapping.lookup(logical_path)!=null) return;
	path_mapping.insert(logical_path,real_path);
	log(_("Registered logical path '%s' to real path '%s'").printf(logical_path,real_path));
	server.add_handler(logical_path,serve_file_callback);
	save_settings();
  }

  public void unregister_path(string logical_path) {
	// For security reasons, don't allow path unregistering if
	// there's no GUI to monitor it
	if (gui_pid == 0) {
	  log(_("Attempted to unregister path without GUI started. Ignoring."));
	  return;
	}

	log(_("Unregistered logical path '%s'").printf(logical_path));
	path_mapping.remove(logical_path);
	save_settings();
  }

  public int get_redirection_type() {
	// GUI should have registered itself before changing redirection type
	if (net==null) return Net.REDIRECTION_TYPE_NONE;
	else return net.redirection_type;
  }

  public void set_redirection_type(int redirection_type) {
	// GUI should have registered itself before changing redirection type
	if (net==null) return;
	net.redirection_type = redirection_type;
  }

  public int get_redirection_status() {
	// GUI should have registered itself before changing redirection status
	if (net==null) return Net.REDIRECTION_STATUS_NONE;
	else return net.redirection_status;
  }

  public void set_ssh_host(string ssh_host) {
	// GUI should have registered itself before doing changes
	if (net==null) return;
	net.ssh_host=ssh_host;
  }

  public void set_ssh_port(string ssh_port) {
	// GUI should have registered itself before doing changes
	if (net==null) return;
	net.ssh_port=ssh_port;
  }

  public void set_ssh_user(string ssh_user) {
	// GUI should have registered itself before doing changes
	if (net==null) return;
	net.ssh_user=ssh_user;
  }

  public void set_ssh_password(string ssh_password) {
	// GUI should have registered itself before doing changes
	if (net==null) return;
	net.ssh_password=ssh_password;
  }

  public HashTable<string,string> get_paths() {
	return path_mapping;
  }

  public string get_requests_stats() {
	return "%u/%u".printf(pending_requests, total_requests);
  }

  [CCode (instance_pos = -1)]
  private bool on_auth_callback (Soup.AuthDomain domain, Soup.Message msg,
								 string username, string password) {
	bool result = (username==auth_user &&
				   Checksum.compute_for_string(ChecksumType.MD5, password)==auth_md5passwd);
	if (!result) {
	  log(_("Invalid authentication asking for path %s").printf(msg.uri.path));
	}
	return result;
  }

  public void serve_file_callback (Soup.Server server, Soup.Message? msg, string path,
								   GLib.HashTable? query, Soup.ClientContext? client) {
	string real_path=null;
	string[] path_tokens=path.split("/",32);
	string composed_path="";
	string translated_path="";

	int j=0;
	for (int i=0;path_tokens[i]!=null;i++) {
	  if (path_tokens[i]=="") continue;
	  composed_path+="/"+path_tokens[i];
	  translated_path=path_mapping.lookup(composed_path);
	  if (translated_path!=null) {
		real_path=translated_path;
		j=i+1;
	  }
	}
	for (int i=j;path_tokens[i]!=null;i++) {
	  real_path+="/"+path_tokens[i];
	}

	pending_requests++;
	total_requests++;
	model_changed();
	msg.finished += () => {
	  pending_requests--;
	  model_changed();
	};

	log(_("Request: %s --> Serving: %s").printf(path,real_path));

	if (real_path==null) {
	  serve_file_callback_default(server,msg,path,query,client);
	  return;
	} else if (!FileUtils.test(real_path,FileTest.EXISTS)) {
	  serve_file_callback_default(server,msg,path,query,client);
	  return;
	} else if (FileUtils.test(real_path,FileTest.IS_REGULAR)) {
	  int f;
	  f=Posix.open(real_path,0,(Posix.mode_t)0);
	  if (f==-1) {
		serve_file_callback_default(server,msg,path,query,client);
		return;
	  }

	  msg.set_status(Soup.KnownStatusCode.OK);

	  string extension=extension_from_path(real_path).down();
	  string mime=null;
	  Posix.Stat stbuf;
	  int64 length=0;

	  if (extension!=null) mime=mimetypes.lookup(extension);
	  if (mime==null) mime="application/x-octet-stream";

	  Posix.fstat(f, out stbuf);
	  length = (int64)stbuf.st_size;

	  msg.response_headers.set_encoding(Soup.Encoding.EOF);
	  msg.response_headers.append("content-type", mime);
	  msg.response_headers.set_content_length(length);
	  msg.response_body.set_accumulate(false); // Save memory

	  ServerContext *context = new ServerContext(server, msg, f, 1024*1024);
	  context->run();
	} else if (FileUtils.test(real_path,FileTest.IS_DIR)) {
	  List<string> files=new List<string>();
	  Dir d=null;
	  try {
		d=Dir.open(real_path,0);
		for (string f=d.read_name(); f!=null; f=d.read_name()) {
		  files.insert_sorted(f,GLib.strcmp);
		}
	  } catch (FileError e) {
		serve_file_callback_default(server,msg,path,query,client);
		return;
	  }

	  msg.set_status(Soup.KnownStatusCode.OK);

	  string response="";
	  response+="<html>\n";
	  response+="<head>\n";
	  response+="<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\" />\n";
	  response+="<title>\n";
	  response+=_("Index of %s\n").printf(path);
	  response+="</title>\n";
	  response+="</head>\n";
	  response+="<body>\n";
	  response+="<!-- generator=\"%s/%s\" -->\n".printf(Config.PACKAGE,Config.VERSION);
	  response+=_("Index of %s\n").printf(path);
	  response+="<ul>\n";

	  foreach (string f in files) {
		response+="<li><a href=\""+path+"/"+f+"\">"+f+"</a></li>";
	  }

	  response+="</ul>\n";
	  response+="<br/><br/><i>";
	  response+=_("Served by <a href=\"http://meiga.igalia.com\">Meiga %s</a>").printf(Config.VERSION);
	  response+="</i>\n";
	  response+="</body>\n</html>\n";
	  msg.set_response("text/html",Soup.MemoryUse.COPY,response,response.len());

	} else {
	  serve_file_callback_default(server,msg,path,query,client);
	}

  }

  public void serve_rss_callback (Soup.Server server, Soup.Message? msg, string path,
								  GLib.HashTable? query, Soup.ClientContext? client) {

	string real_path=null;
	string[] path_tokens=path.split("/",32);
	string composed_path="";
	string translated_path="";

	int j=0;
	// Ignoring first path element "/rss"
	for (int i=2;path_tokens[i]!=null;i++) {
	  if (path_tokens[i]=="") continue;
	  composed_path+="/"+path_tokens[i];
	  translated_path=path_mapping.lookup(composed_path);
	  if (translated_path!=null) {
		real_path=translated_path;
		j=i+1;
	  }
	}
	for (int i=j;path_tokens[i]!=null;i++) {
	  real_path+="/"+path_tokens[i];
	}

	log(_("Request: %s --> Serving (RSS mode): %s").printf(path,real_path));

	Soup.URI uri=msg.get_uri().copy();
	string base_url="%s://%s:%u".printf(uri.scheme,uri.host,uri.port);

	if (real_path==null) {
	  serve_file_callback_default(server,msg,path,query,client);
	  return;
	} else if (!FileUtils.test(real_path,FileTest.EXISTS)) {
	  serve_file_callback_default(server,msg,path,query,client);
	  return;
	} else if (FileUtils.test(real_path,FileTest.IS_REGULAR)) {
	  MappedFile f=null;
	  try {
		f=new MappedFile(real_path,false);
	  } catch (FileError e) {
		serve_file_callback_default(server,msg,path,query,client);
		return;
	  }

	  msg.set_status(Soup.KnownStatusCode.OK);

	  string extension=extension_from_path(real_path);
	  string mime=null;

	  if (extension!=null) mime=mimetypes.lookup(extension);
	  if (mime==null) mime="application/x-octet-stream";

	  // f.get_contents() returns unmanaged memory, so Vala will segfault trying to
	  // unref a normal string. AN unmanaged string shoyuld be used (string *)
	  msg.set_response(mime,Soup.MemoryUse.COPY,(string *)f.get_contents(),f.get_length());
	} else if (FileUtils.test(real_path,FileTest.IS_DIR)) {
	  msg.set_status(Soup.KnownStatusCode.OK);
	  RssFeed rss=RssFeed.new_from_directory(real_path,
											 base_url+composed_path,
											 composed_path,
											 _("Documents under %s").printf(composed_path));

	  string response=rss.to_string();
	  msg.set_response("application/rss+xml",Soup.MemoryUse.COPY,response,response.len());
	} else {
	  serve_file_callback_default(server,msg,path,query,client);
	}
  }

  public void serve_file_callback_default (Soup.Server server, Soup.Message msg, string path,
										   GLib.HashTable? query, Soup.ClientContext? client) {
	serve_error(msg,path,Soup.KnownStatusCode.NOT_FOUND,_("File not found"));
  }

  public void serve_error(Soup.Message msg, string path, Soup.KnownStatusCode error, string error_message) {
	msg.set_status(error);
	msg.set_response("text/html",Soup.MemoryUse.COPY,error_message,error_message.len());
	log("%d - %s: %s".printf(error,error_message,path));
  }

  private string? extension_from_path(string path) {
	string[] token=path.split(".");
	int i=0;
	while (token[i]!=null) i++;
	if (i>0) return token[i-1];
	else return null;
  }

  public static void main(string[] args) {
	Intl.setlocale(LocaleCategory.ALL,"");
	Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
	Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain(Config.GETTEXT_PACKAGE);

	MeigaServer s=new MeigaServer();
	s.initialize();
	Gtk.init(ref args);
	Gtk.main();
	return;
  }

}
