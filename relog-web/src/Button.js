import styles from './Button.module.css';

const Button = (props) => {
    let className = styles.Button;
    if (props.kind === "inline") {
        className += " " + styles.inline;
    }

    let tooltip = "";
    if (props.tooltip != undefined) {
        tooltip = <span className={styles.tooltip}>{props.tooltip}</span>;
    }

    return (
        <button className={className} onClick={props.onClick}>
            {tooltip}
            {props.label}
        </button>
    );
};

export default Button;