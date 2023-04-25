const esbuild = require('esbuild')
const path = require("path");

esbuild.build({
    entryPoints: ["js/app.js"],
    bundle: true,
    outfile: path.resolve(__dirname, "../priv/static/assets/js/app.js")
})

