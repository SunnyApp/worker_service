importScripts('/require.js');

// Get a URL object for the service worker script's location.
const myURL = new URL(self.location);
console.log("My URL: ", myURL);
const grl = myURL.searchParams.get('grl');
console.log("grl=", grl.toString());

require({
        paths: {},
        baseUrl: "/"
    },
    [grl.toString()],
    function (a, b, c) {
        const mod = require(grl.toString());
        const keys = Object.keys(mod)
        for (const i in keys) {
            const p = mod[keys[i]];
            if (p["main"]) {
                p["main"]();
                return;
            }
        }
        throw "No main found!";
    }
);