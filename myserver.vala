using GLib;
using Soup;
using Gtk;

[DBus (name = "org.gnome.FromGnomeToTheWorld")]
public class FromGnomeToTheWorld : GLib.Object {
 public Myserver server;
 
 public FromGnomeToTheWorld() {
 }

 public void register_path(string real_path, string logical_path) {
  server.register_path(real_path,logical_path);
 }
  
 public void unregister_path(string logical_path) {
  server.unregister_path(logical_path);
 }
 
 public HashTable<string,string> get_paths() {
  return server.get_paths();
 }

}

public class Myserver : GLib.Object {
 const string MIME_TYPES_FILE="/etc/mime.types";

 private int port;
 private Soup.Server server;
 private GLib.HashTable<string,string> path_mapping;
 private GLib.HashTable<string,string> mimetypes;
 private FromGnomeToTheWorld exposed;
 
 public Myserver() {
 }

 public void initialize() {
  port=8001;
  
  initialize_mimetypes();
  path_mapping=new GLib.HashTable<string,string>(GLib.str_hash,GLib.str_equal);
    
  server=new Server(Soup.SERVER_PORT,port);
  server.add_handler("/",serve_file_callback_default);
  server.run_async();
  
  initialize_dbus();
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
    stderr.printf("Error opening file %s\n",MIME_TYPES_FILE);
  } 
 }

 private void initialize_dbus() {
  try {
   this.exposed=new FromGnomeToTheWorld();
   this.exposed.server=this;
  
   var conn = DBus.Bus.get(DBus.BusType.SESSION);
   conn.register_object ("/org/gnome/FromGnomeToTheWorld", (GLib.Object)this.exposed);
  } catch (Error e) {
   stderr.printf("Error registering DBUS server: %s\n",e.message);
  }
 }

 public void set_port(int port) {
  this.port=port;
 }

 public void register_path(string real_path, string logical_path) {
  if (path_mapping.lookup(logical_path)!=null) return;
  path_mapping.insert(logical_path,real_path);
  stderr.printf("Registered logical path '%s' to real path '%s'\n",logical_path,real_path);
  server.add_handler(logical_path,serve_file_callback);
 }

 public void unregister_path(string logical_path) {
  stderr.printf("Unregistered logical path '%s'\n",logical_path);
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
  
  stderr.printf("Request: %s --> Serving: %s\n",path,real_path);
  
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
    
   msg.set_response(mime,Soup.MemoryUse.COPY,(string)f.get_contents(),f.get_length());
  } else if (FileUtils.test(real_path,FileTest.IS_DIR)) {
   Dir d=null;
   try {
    d=Dir.open(real_path,0);
   } catch (FileError e) {
     serve_file_callback_default(server,msg,path,query,client);
     return;
   }
   
   msg.set_status(Soup.KnownStatusCode.OK);
   
   string response="";
   response+="<html>\n<body>\n";
   response+="Index of "+path+"\n";
   response+="<ul>\n";
   
   for (string f=d.read_name(); f!=null; f=d.read_name()) {
    response+="<li><a href=\""+path+"/"+f+"\">"+f+"</a></li>";
   }
   
   response+="</ul>\n";
   response+="</body>\n</html>\n";
   msg.set_response("text/html",Soup.MemoryUse.COPY,response,response.len());
   
  } else {
   serve_file_callback_default(server,msg,path,query,client);
  }
  
 }

 public void serve_file_callback_default (Soup.Server server, Soup.Message msg, string path,
  GLib.HashTable? query, Soup.ClientContext? client) {
  serve_error(msg,path,Soup.KnownStatusCode.NOT_FOUND,"File not found");
 }
 
 public void serve_error(Soup.Message msg, string path, Soup.KnownStatusCode error, string error_message) {
  msg.set_status(error);
  msg.set_response("text/html",Soup.MemoryUse.COPY,error_message,error_message.len());
  stderr.printf("%d - %s: %s\n",error,error_message,path);
 }
 
 private string? extension_from_path(string path) {
  string[] token=path.split(".");
  int i=0;
  while (token[i]!=null) i++;
  if (i>0) return token[i-1];
  else return null;
 }
 
 public static void main(string[] args) {
  Myserver s=new Myserver();
  s.initialize();
  s.register_path("/home/enrique/IMAGENES","/pictures");
  Gtk.init(ref args);
  Gtk.main();
  return;
 }
 
}
