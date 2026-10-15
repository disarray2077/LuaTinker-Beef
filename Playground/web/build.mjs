import * as esbuild from "esbuild";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.resolve(root, "../../build/wasm/playground");
const watch = process.argv.includes("--watch");
await mkdir(output, { recursive: true });
const options = {
  absWorkingDir: root,
  entryPoints: ["src/main.jsx"],
  bundle: true,
  outfile: path.join(output, "ui.js"),
  format: "esm",
  jsx: "automatic",
  target: "es2022",
  minify: !watch,
  sourcemap: watch,
  define: {
    "process.env.NODE_ENV": JSON.stringify(
      watch ? "development" : "production",
    ),
  },
  logLevel: "info",
  plugins: [
    {
      name: "playground-html",
      setup(build) {
        build.onEnd(async (result) => {
          if (result.errors.length) return;
          const shell = await readFile(path.join(root, "index.html"), "utf8");
          await writeFile(
            path.join(output, "LuaTinkerPlayground.html"),
            shell.replaceAll(
              "__PLAYGROUND_BUILD_VERSION__",
              String(Date.now()),
            ),
          );
        });
      },
    },
  ],
};
if (watch) {
  const context = await esbuild.context(options);
  await context.watch();
} else await esbuild.build(options);
