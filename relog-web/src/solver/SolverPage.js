import React from "react";
import { useParams } from "react-router-dom";
import Footer from "../common/Footer";
import Header from "../common/Header";
import LogBlock from "./LogBlock";
import FilesBlock from "./FilesBlock";

const SolverPage = () => {
  const params = useParams();

  return (
    <>
      <Header title="Solver"></Header>
      <div id="contentBackground">
        {" "}
        <div id="content">
          <LogBlock job={params.job_id} />
          <FilesBlock job={params.job_id} />
        </div>
      </div>
      <Footer />
    </>
  );
};

export default SolverPage;
