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

public class RssNode : GLib.Object {

  public string title { get; set; default=_("No title"); }
  public string link { get; set; default=""; }
  public Time time { get; set; }
  public string description { get; set; default=_("No description"); }
  public string content { get; set; default=_("No content"); }

  public RssNode() {
	this.time=Time();
  }

  public string to_string() {
	return
    "   <title>"+title+"</title>\n" +
    "   <link>"+link+"</link>\n" +
    "\n" +
    "   <pubDate>"+time.to_string()+"</pubDate>\n" +
    "   <guid>"+link+"</guid>\n" +
    "   <description><![CDATA["+description+"]]></description>\n" +
    "     <content:encoded><![CDATA["+content+"]]></content:encoded>\n";
  }

}

public class RssFeed : GLib.Object {

  public string title { get; set; default=_("No title"); }
  public string link { get; set; default=""; }
  public string description { get; set; default=_("No description"); }
  public Time time { get; set; }
  public string generator { get; set; default="%s/%s".printf(Config.PACKAGE,Config.VERSION); }
  public string language { get; set; default=_("en"); }

  // It segfaults if defined as a property
  public List<RssNode> nodes;

  public RssFeed() {
	this.time=Time();
	this.nodes=new List<RssNode>();
  }

  public string to_string() {
	string result=
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!-- generator=\""+generator+"\" -->\n" +
    "<rss version=\"2.0\" \n" +
    "\txmlns:content=\"http://purl.org/rss/1.0/modules/content/\"\n" +
    "\txmlns:wfw=\"http://wellformedweb.org/CommentAPI/\"\n" +
    "\txmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n" +
    "\t>\n" +
    "\n" +
    "\t<channel>\n" +
    "\t\t<title>"+title+"</title>\n" +
    "\t\t<link>"+link+"</link>\n" +
    "\t\t<description>"+description+"</description>\n" +
    "\t\t<pubDate>"+time.to_string()+"</pubDate>\n" +
    "\n" +
    "\t\t<generator>"+generator+"</generator>\n" +
    "\t\t<language>"+language+"</language>\n";

	foreach (RssNode node in nodes) {
	  result+=
      "\t\t<item>\n" +
      "\t\t" + node.to_string() +
      "\t\t</item>\n";
	}

	result+=
    "\t</channel>\n" +
    "</rss>\n";

	return result;
  }

  public static RssFeed new_from_directory(string path, string base_url, string title, string description) {
	RssFeed rss=new RssFeed();

	if (title!=null) rss.title=title;
	if (description!=null) rss.description=description;

	try {
	  File dir=File.new_for_path(path);
	  FileInfo info=dir.query_info(FILE_ATTRIBUTE_TIME_MODIFIED, FileQueryInfoFlags.NONE, null);
	  uint64 time=info.get_attribute_uint64(FILE_ATTRIBUTE_TIME_MODIFIED);
	  rss.time=Time.local((time_t)time);

	  FileEnumerator files=dir.enumerate_children("standard::*,"+FILE_ATTRIBUTE_TIME_MODIFIED, FileQueryInfoFlags.NONE, null);
	  while ((info=files.next_file(null))!=null) {
		RssNode node=new RssNode();
		string name=info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME);
		node.title=name;
		node.link=base_url+"/"+name;
		time=info.get_attribute_uint64(FILE_ATTRIBUTE_TIME_MODIFIED);
		node.time=Time.local((time_t)time);

		FileType type=info.get_file_type();
		string mimetype=info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);

		if (type==FileType.DIRECTORY) {
		  File dir2=File.new_for_path(path+"/"+name);
		  FileEnumerator files2=dir2.enumerate_children(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME, FileQueryInfoFlags.NONE, null);
		  FileInfo info2=null;
		  string node_description="<ul>\n";

		  while ((info2=files2.next_file(null))!=null) {
			string name2=info2.get_attribute_string(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME);
			string link2=base_url+"/"+name+"/"+name2;
			node_description+="<li><a href=\""+link2+"\">"+name2+"</a></li>\n";
		  }
		  node_description+="<ul>\n";
		  node.description=node_description;
		} else {
		  if (mimetype==null) mimetype="application/x-octet-stream";
		  if (mimetype.has_prefix("image/")) {
			node.description="<img src=\"%s\" width=\"300\" />".printf(node.link);
		  } else if (mimetype=="text/plain") {
			MappedFile f=new MappedFile(path+"/"+name,false);
			node.description="<pre>%s</pre>\n".printf((string *)f.get_contents());
		  } else if (mimetype=="text/html") {
			MappedFile f=new MappedFile(path+"/"+name,false);
			node.description="%s\n".printf((string *)f.get_contents());
		  } else {
			node.description=_("<a href=\"%s\">Download %s</a>\n").printf(node.link,node.title);
		  }
		}
		node.content=node.description;

		rss.nodes.append(node);
	  }

	} catch (Error e) {
	  stderr.printf(_("RssFeed.new_from_directory(): Error\n"));
	}

	return rss;
  }

}
