using GLib;
using Soup;
using Posix;

public class ServerContext : GLib.Object {
  /* Flag to check if on_request_aborted is registered */
  public static bool abort_handler_registered = false;

  /* Soup server */
  public Soup.Server server;

  /* Request being processed */
  public Soup.Message msg;

  /* Buffer size (bytes) */
  public size_t bufsize;

  /* Reading buffer */
  public void *buffer;

  /* Bytes read in the buffer */
  public ssize_t n;

  /* File descriptor */
  public int fd;

  public ServerContext(Soup.Server server,
					   Soup.Message msg,
					   int fd,
					   size_t bufsize) {
	this.server = server;
	this.msg = msg;
	this.fd = fd;
	this.bufsize = bufsize;	
  }

  public void run() {
	this.ref();
	msg.set_data("meiga-server-context", (void *)this);
	if (!abort_handler_registered) {
	  server.request_aborted += on_request_aborted;
	  abort_handler_registered = true;
	}
	msg.wrote_chunk += on_wrote_chunk;
	Idle.add(serve_chunk);
  }

  public void cleanup() {
	msg.set_data("meiga-server-context", null);
	if (buffer!=null) {
	  delete buffer;
	  buffer = null;
	}
	if (fd>0) {
	  Posix.close(fd);
	  fd=-1;
	  this.unref();
	}
  }

  public bool serve_chunk() {
    if (fd<=0) return false;

	buffer = (void *)new char[bufsize];
	n=Posix.read(fd, (void *)buffer, bufsize);

	if (n>0) {
	  msg.response_body.append(Soup.MemoryUse.TAKE,
	  						   buffer, (size_t)n);
	  server.unpause_message(msg);
	} else {
	  msg.response_body.complete();
	  server.unpause_message(msg);
	  buffer = null;
	  cleanup();
	}
	return false;
  }

  public static void on_wrote_chunk (Soup.Message msg) {
	ServerContext *sc;
	sc = (ServerContext*)msg.get_data<ServerContext*>("meiga-server-context");
	if (sc!=null) sc->serve_chunk();
  }

  public static void on_request_aborted (Soup.Server server,
										 Soup.Message msg,
										 Soup.ClientContext client) {
	ServerContext *sc;
	sc = (ServerContext*)msg.get_data<ServerContext*>("meiga-server-context");
	if (sc!=null) {
	  sc->cleanup();
	}
  }

}