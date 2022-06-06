import { useState } from "react";
import { useEffect } from "react";
import Section from "../common/Section";
import Card from "../common/Card";
import styles from "./LogBlock.module.css";
import { useRef } from "react";

const LogBlock = (props) => {
  const [log, setLog] = useState();
  const preRef = useRef(null);

  const fetchLog = async () => {
    const response = await fetch(`/jobs/${props.job}/solve.log`);
    const data = await response.text();
    if (log !== data) {
      setLog(data);
    }
  };

  // Fetch log periodically from the server
  useEffect(() => {
    fetchLog();
    const interval = setInterval(() => {
      fetchLog();
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  // Scroll to bottom whenever the log is updated
  useEffect(() => {
    preRef.current.scrollTop = preRef.current.scrollHeight;
  }, [log]);

  return (
    <>
      <Section title="Optimization Log" />
      <Card>
        <pre ref={preRef} className={styles.log}>
          {log}
        </pre>
      </Card>
    </>
  );
};

export default LogBlock;
