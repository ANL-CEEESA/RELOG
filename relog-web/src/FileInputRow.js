import form_styles from './Form.module.css';
import Button from './Button';

const FileInputRow = (props) => {

    let tooltip = "";
    if (props.tooltip != undefined) {
        tooltip = <Button label="?" kind="inline" tooltip={props.tooltip} />;
    }

    return <div className={form_styles.FormRow}>
        <label>{props.label}</label>
        <input type="text" disabled="disabled" />
        <Button label="Upload" kind="inline" />
        <Button label="Clear" kind="inline" />
        <Button label="Template" kind="inline" />
        {tooltip}
    </div>;
};

export default FileInputRow;