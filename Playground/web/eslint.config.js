import js from "@eslint/js";
import { defineConfig } from "eslint/config";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";

export default defineConfig(
  {
    files: ["**/*.{js,jsx,mjs}"],
    extends: [js.configs.recommended],
  },
  {
    files: ["src/**/*.{js,jsx}"],
    extends: [reactHooks.configs.flat.recommended],
    languageOptions: {
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
  },
  {
    files: ["*.{js,mjs}", "tests/**/*.js"],
    languageOptions: { globals: globals.node },
  },
);
