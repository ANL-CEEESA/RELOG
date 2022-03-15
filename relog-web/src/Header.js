import styles from './Header.module.css';

const Header = () => {
    return (
        <div className={styles.HeaderBox}>
            <div className={styles.HeaderContent}>
                <h1>RELOG</h1>
            </div>
        </div>
    );
};

export default Header;