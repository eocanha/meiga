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

public class MeigaServer : GLib.Object {
  const string MIME_TYPES_FILE="/etc/mime.types";

  private int port;
  private Soup.Server server;
  private GLib.HashTable<string,string> path_mapping;
  private GLib.HashTable<string,string> mimetypes;
  private Meiga exposed;
  private Net net;

  public Log logger { public get; private set; default=null; }
  public uint gui_pid { public get; private set; default=0; }
  public string display { public get; private set; default=null; }

  public signal void model_changed();

  public MeigaServer() {
  }

  private void log(string msg) {
	if (logger!=null) logger.log(msg);
  }

  public void initialize() {
	logger = new Log();

	port=8001;

	initialize_mimetypes();
	path_mapping=new GLib.HashTable<string,string>(GLib.str_hash,GLib.str_equal);

	server=new Server(Soup.SERVER_PORT,port);
	server.add_handler("/",serve_file_callback_default);
	server.add_handler("/rss",serve_rss_callback);
	server.run_async();

	initialize_dbus();
  }

  public void initialize_net() {
	net = new Net();
	net.logger = logger;
	net.port = port;
	net.display = display;
	net.forward_start();
	net.notify["url"] += (s, p) => {
	  log(_("External URL: %s").printf(get_public_url()));
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

  public string get_public_url() {
	return net.url;
  }

  public void shutdown() {
	Gtk.main_quit();
	net.forward_stop();
  }

  public void set_port(int port) {
	this.port=port;
  }

  public void register_gui(uint gui_pid, string display) {
	this.gui_pid = gui_pid;
	this.display = display;
	if (this.net == null) initialize_net();
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
  }

  public HashTable<string,string> get_paths() {
	return path_mapping;
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

	log(_("Request: %s --> Serving: %s").printf(path,real_path));

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

	  string extension=extension_from_path(real_path).down();
	  string mime=null;

	  if (extension!=null) mime=mimetypes.lookup(extension);
	  if (mime==null) mime="application/x-octet-stream";

	  // f.get_contents() returns unmanaged memory, so Vala will segfault trying to
	  // unref a normal string. AN unmanaged string shoyuld be used (string *)
	  msg.set_response(mime,Soup.MemoryUse.COPY,(string *)f.get_contents(),f.get_length());
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
	  response+="<html>\n<body>\n";
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
