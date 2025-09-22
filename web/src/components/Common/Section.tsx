import styles from "./Section.module.css";

interface SectionProps { 
  title: string;
}

const Section = ({ title }: SectionProps) => {
  return <h2 className={styles.Section}>{title}</h2>;
};

export default Section;
