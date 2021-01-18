importScripts('/require.js');

// Get a URL object for the service worker script's location.
const myURL = new URL(self.location);
console.log("Got inbound URL: ", myURL);
const gkey = myURL.searchParams.get('key');
console.log("key=", gkey.toString());

require({
        paths: {},
        baseUrl: "/"
    },
    ["/main.dart.js"],
    function () {
        const mod = require("/main.dart.js");
        const keys = Object.keys(mod)
        for (const i in keys) {
            const p = mod[keys[i]];
            if (p && p["mainWorker"]) {
                p["mainWorker"](gkey.toString());
                return;
            }
        }
        throw "No mainWorker found.  This function should be defined at the top level, in your main.dart file";
    }
);