/*
 * UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
 * Copyright (C) 2020-2025, UChicago Argonne, LLC. All rights reserved.
 * Released under the modified BSD license. See COPYING.md for more details.
 */

import styles from "./Header.module.css";
import SiteHeaderButton from "../Common/Buttons/SiteHeaderButton";
import { useRef } from "react";
import FileUploadElement from "../Common/Buttons/FileUploadElement";

interface HeaderProps {
  onClear: () => void;
  onSave: () => void;
  onLoad: () => void;
}

function Header(props: HeaderProps) {
  const fileElem = useRef<FileUploadElement>(null);

  function onLoad() {}

  return (
    <div className={styles.HeaderBox}>
      <div className={styles.HeaderContent}>
        <h1>RELOG</h1>
        <h2>Case Builder</h2>
        <div className={styles.buttonContainer}>
          <SiteHeaderButton title="Clear" onClick={props.onClear} />
          <SiteHeaderButton title="Load" onClick={onLoad} />
          <SiteHeaderButton title="Save" onClick={props.onSave} />
        </div>
        <FileUploadElement ref={fileElem} accept=".json,.json.gz" />
      </div>
    </div>
  );
}

export default Header;
