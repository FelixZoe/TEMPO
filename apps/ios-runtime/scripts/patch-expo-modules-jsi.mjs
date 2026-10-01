import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const candidates = [
  join(
    "node_modules",
    "expo",
    "node_modules",
    "expo-modules-jsi",
    "apple",
    "Sources",
    "ExpoModulesJSI",
    "Coding",
    "JavaScriptCodable+Date.swift",
  ),
  join(
    "node_modules",
    "expo-modules-jsi",
    "apple",
    "Sources",
    "ExpoModulesJSI",
    "Coding",
    "JavaScriptCodable+Date.swift",
  ),
];

let found = 0;

for (const path of candidates) {
  if (!existsSync(path)) continue;

  found += 1;
  const source = readFileSync(path, "utf8");
  const patched = source.replace(
    "abs(milliseconds) <= maxJavaScriptDateMilliseconds",
    "milliseconds.magnitude <= maxJavaScriptDateMilliseconds",
  );

  if (patched !== source) {
    writeFileSync(path, patched);
    console.log(`[postinstall] Patched Swift 6.2 Date compatibility in ${path}`);
  } else if (source.includes("milliseconds.magnitude <= maxJavaScriptDateMilliseconds")) {
    console.log(`[postinstall] Swift 6.2 Date compatibility already present in ${path}`);
  } else {
    throw new Error(`Unexpected expo-modules-jsi Date source in ${path}`);
  }
}

if (found === 0) {
  throw new Error("expo-modules-jsi Date source was not found after npm install");
}
