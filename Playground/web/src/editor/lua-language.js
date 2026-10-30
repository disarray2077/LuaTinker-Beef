import { StreamLanguage } from "@codemirror/language";
import { lua } from "@codemirror/legacy-modes/mode/lua";
import {
  completeAnyWord,
  completeFromList,
  snippetCompletion,
} from "@codemirror/autocomplete";

const language = StreamLanguage.define(lua);
const keywords =
  "and break do else elseif end false for function goto if in local nil not or repeat return then true until while";
const functions =
  "assert collectgarbage dofile error getmetatable ipairs load loadfile next pairs pcall print rawequal rawget rawlen rawset require select setmetatable tonumber tostring type warn xpcall";
const libraries = "coroutine debug io math os package string table utf8";
const completions = [
  ...keywords.split(" ").map((label) => ({ label, type: "keyword" })),
  ...functions.split(" ").map((label) => ({ label, type: "function" })),
  ...libraries.split(" ").map((label) => ({ label, type: "namespace" })),
  snippetCompletion("if ${condition} then\n\t${}\nend", {
    label: "if … then",
    type: "keyword",
    detail: "if block",
  }),
  snippetCompletion("local function ${name}(${args})\n\t${}\nend", {
    label: "local function",
    type: "keyword",
    detail: "function block",
  }),
  snippetCompletion("for ${i} = ${1}, ${count} do\n\t${}\nend", {
    label: "for … do",
    type: "keyword",
    detail: "numeric loop",
  }),
  snippetCompletion("for ${i}, ${value} in ipairs(${items}) do\n\t${}\nend", {
    label: "for … in ipairs",
    type: "keyword",
    detail: "sequence loop",
  }),
];

export const luaSupport = [
  language,
  language.data.of({ autocomplete: completeFromList(completions) }),
  language.data.of({ autocomplete: completeAnyWord }),
];
