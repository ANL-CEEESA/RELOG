import styles from "./Card.module.css";

const Card = (props) => {
  return <div className={styles.Card}>{props.children}</div>;
};

export default Card;
