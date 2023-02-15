import React from "react";
import ReactDOM from "react-dom";
import "./index.css";
import InputPage from "./casebuilder/InputPage";
import SolverPage from "./solver/SolverPage";
import { Route, BrowserRouter, Switch, Redirect } from "react-router-dom";

export const SERVER_URL = "";

ReactDOM.render(
  <BrowserRouter>
    <React.StrictMode>
      <Switch>
        <Route path="/casebuilder">
          <InputPage />
        </Route>
        <Route path="/solver/:job_id">
          <SolverPage />
        </Route>
        <Route path="/">
          <Redirect to="/casebuilder" />
        </Route>
      </Switch>
    </React.StrictMode>
  </BrowserRouter>,
  document.getElementById("root")
);
