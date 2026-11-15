/// <reference types="vite/client" />
// Module map for convex-test, globbed from convex/ so tests in subfolders resolve function paths.
export const modules = import.meta.glob("./**/*.*s");
