/*
 * RELOG: Supply Chain Analysis and Optimization
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import React from "react";
import ReactDOM from "react-dom/client";
import reportWebVitals from "./reportWebVitals";
import CaseBuilder from "./components/CaseBuilder/CaseBuilder";

const root = ReactDOM.createRoot(
  document.getElementById("root") as HTMLElement,
);

root.render(
  <React.StrictMode>
    <CaseBuilder />
  </React.StrictMode>,
);

reportWebVitals();
