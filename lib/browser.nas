import("unix");
import("options");

if(platform=="macosx") {
    var browser = "open"
} else {
    var browser = unix.getenv("BROWSER");
    if(browser==nil) browser = "firefox";
}
options.add_option("browser", browser);

var open_uri = func(uri) {
    var prog = options.get("browser");
    unix.spawn(sprintf("%s %s",prog,uri));
}
