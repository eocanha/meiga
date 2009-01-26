using GLib;

public class RssNode : GLib.Object {

 public string title { get; set; default="No title"; }
 public string link { get; set; default=""; }
 public Time time { get; set; }
 public string description { get; set; default="No description"; }
 public string content { get; set; default="No content"; }
 
 public RssNode() {
  this.time=Time();
 }
 
 public string to_string() {
  return
    "   <title>"+title+"</title>\n" +
    "   <link>"+link+"</link>\n" +
    "\n" +
    "   <pubDate>"+time.to_string()+"</pubDate>\n" +
    "   <description><![CDATA["+description+"]]></description>\n" +
    "     <content:encoded><![CDATA["+content+"]]></content:encoded>\n";
 }
 
}

public class RssFeed : GLib.Object {
  
 public string title { get; set; default="No title"; }
 public string link { get; set; default=""; }
 public string description { get; set; default="No description"; }
 public Time time { get; set; }
 public string generator { get; set; default="From Gnome to the world"; } 
 public string language { get; set; default="en"; } 
 public List<RssNode> nodes {
  get { return this.nodes; }
  set { this.nodes=value; }
 }
 
 public RssFeed() {
  this.time=Time();
 }
 
 private string to_string() {
  string result=
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!-- generator=\""+generator+"\" -->\n" +
    "<rss version=\"2.0\" \n" +
    " xmlns:content=\"http://purl.org/rss/1.0/modules/content/\"\n" +
    " xmlns:wfw=\"http://wellformedweb.org/CommentAPI/\"\n" +
    " xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n" +
    " >\n" +
    "\n" +
    "<channel>\n" +
    " <title>"+title+"</title>\n" +
    " <link>"+link+"</link>\n" +
    " <description>"+description+"</description>\n" +
    " <pubDate>"+time.to_string()+"</pubDate>\n" +
    "\n" +
    " <generator>"+generator+"</generator>\n" +
    " <language>"+language+"</language>\n";
    
  foreach (RssNode node in nodes) {
    result+=
      " <item>\n" +
      node.to_string() +
      " </item>\n";
  }
    
  result+=
    "</channel>\n" +
    "</rss>\n";
  return result;
 } 

}