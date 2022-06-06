import { useState } from "react";
import { useEffect } from "react";
import Section from "../common/Section";
import Card from "../common/Card";
import styles from "./FilesBlock.module.css";
import { useRef } from "react";

const FilesBlock = (props) => {
  const [filesFound, setFilesFound] = useState(false);

  const fetchFiles = async () => {
    const response = await fetch(`/jobs/${props.job}/output.json`);
    if (response.ok) {
      setFilesFound(true);
    }
  };

  // Fetch files periodically from the server
  useEffect(() => {
    fetchFiles();
    console.log(filesFound);
    if (!filesFound) {
      const interval = setInterval(() => {
        fetchFiles();
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [filesFound]);

  let content = <div className={styles.nodata}>No files available</div>;
  if (filesFound) {
    content = (
      <div className={styles.files}>
        <a href={`/jobs/${props.job}/output.zip`}>output.zip</a>
      </div>
    );
  }

  return (
    <>
      <Section title="Output Files" />
      <Card>{content}</Card>
    </>
  );
};

export default FilesBlock;
