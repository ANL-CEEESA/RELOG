import form_styles from './Form.module.css';
import Button from './Button';

const TextInputRow = (props) => {
    let unit = "";
    if (props.unit) {
        unit = <span className={form_styles.FormRow_unit}>({props.unit})</span>;
    }

    let tooltip = "";
    if (props.tooltip != undefined) {
        tooltip = <Button label="?" kind="inline" tooltip={props.tooltip} />;
    }

    return <div className={form_styles.FormRow}>
        <label>
            {props.label} {unit}
        </label>
        <input
            type="text"
            placeholder={props.default}
            disabled={props.disabled}
            value={props.value}
            onChange={e => props.onChange(e.target.value)}
        />
        {tooltip}
    </div>;
};

export default TextInputRow;