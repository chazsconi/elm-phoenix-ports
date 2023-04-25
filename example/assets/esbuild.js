const esbuild = require('esbuild')
const { sassPlugin } = require('esbuild-sass-plugin')
const path = require("path");

const loader = {}

const plugins = [
    sassPlugin()
]

let opts = {
    entryPoints: ["js/app.js"],
    bundle: true,
    format: "cjs",
    target: ["es2016"],
    outfile: path.resolve(__dirname, "../priv/static/assets/js/app.js"),
    external: ["/images/*"],
    logLevel: 'info',
    loader,
    plugins
}
esbuild.build(opts)

