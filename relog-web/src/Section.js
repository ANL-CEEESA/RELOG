import styles from './Section.module.css';

const Section = (props) => {
    return <h2 className={styles.Section}>{props.title}</h2>;
};

export default Section;