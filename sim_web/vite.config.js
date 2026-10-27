import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// The source component lives at the repo root (../iv_device_3d_sim.jsx), so its
// bare imports ("three", "react") would resolve against the repo root's
// node_modules, which doesn't exist. Alias them to this project's node_modules.
const r = (p) => fileURLToPath(new URL(`./node_modules/${p}`, import.meta.url));

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      three: r("three"),
      react: r("react"),
      "react-dom": r("react-dom"),
    },
  },
  server: {
    // Allow importing the source .jsx that lives one level up (repo root).
    fs: { allow: [".."] },
  },
});
