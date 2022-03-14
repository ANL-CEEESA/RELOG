import form_styles from './Form.module.css'
import Button from './Button'

const DictInputRow = (props) => {
    let unit = "";
    if (props.unit) {
        unit = <span className={form_styles.FormRow_unit}>({props.unit})</span>
    }

    let tooltip = "";
    if (props.tooltip != undefined) {
        tooltip = <Button label="?" kind="inline" tooltip={props.tooltip} />
    }

    let value = {}
    if (props.value != undefined) {
        value = props.value;
    }
    if (props.disableKeys === undefined) {
        value[""] = "";
    }

    const form = []
    Object.keys(value).forEach((key, index) => {
        let label = <span>{props.label} {unit}</span>;
        if (index > 0) {
            label = "";
        }
        form.push(
            <div className={form_styles.FormRow} key={index}>
                <label>{label}</label>
                <input
                    type="text"
                    data-index={index}
                    value={key}
                    placeholder={props.keyPlaceholder}
                    disabled={props.disableKeys}
                />
                <input
                    type="text"
                    data-index={index}
                    value={value[key]}
                    placeholder={props.valuePlaceholder}
                />
                {tooltip}
            </div>
        );
    });

    return <>
        {form}
    </>;
}

export default DictInputRow;