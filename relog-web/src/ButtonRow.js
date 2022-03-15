import styles from './ButtonRow.module.css';

const ButtonRow = (props) => {
    return <div className={styles.ButtonRow}>{props.children}</div>;
};

export default ButtonRow;