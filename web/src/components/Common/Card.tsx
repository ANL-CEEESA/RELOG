import styles from "./Card.module.css";
import React, { ReactNode } from "react";


interface CardProps {
  children: ReactNode;
}

const Card: React.FC<CardProps> = ({children}) => {
  return <div className={styles.Card}>{children}</div>;
};

export default Card;
