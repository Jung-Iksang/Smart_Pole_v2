import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import IvDevice3DSim from "../../iv_device_3d_sim.jsx";

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <IvDevice3DSim />
  </StrictMode>
);
