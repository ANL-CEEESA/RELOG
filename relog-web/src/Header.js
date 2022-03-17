import styles from "./Header.module.css";

const Header = (props) => {
  return (
    <div className={styles.HeaderBox}>
      <div className={styles.HeaderContent}>
        <h1>RELOG</h1>
        <h2>{props.title}</h2>
        <div style={{ float: "right", paddingTop: "5px" }}>
          {props.children}
        </div>
      </div>
    </div>
  );
};

export default Header;
