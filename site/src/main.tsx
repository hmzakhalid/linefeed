import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./brand-tokens.css";
import "./styles.css";

const root = document.getElementById("root");
if (!root) throw new Error("Linefeed site root was not found");

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
