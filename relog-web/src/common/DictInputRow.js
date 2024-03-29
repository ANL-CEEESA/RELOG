import form_styles from "./Form.module.css";
import Button from "./Button";
import { validate } from "./Form";

const DictInputRow = (props) => {
  const dict = { ...props.value };
  if (!props.disableKeys) {
    dict[""] = "0";
  }

  let unit = "";
  if (props.unit) {
    unit = <span className={form_styles.FormRow_unit}>({props.unit})</span>;
  }

  let tooltip = "";
  if (props.tooltip !== undefined) {
    tooltip = <Button label="?" kind="inline" tooltip={props.tooltip} />;
  }

  const onChangeValue = (key, v) => {
    const newDict = { ...dict };
    newDict[key] = v;
    props.onChange(newDict);
  };

  const onChangeKey = (prevKey, newKey) => {
    const newDict = renameKey(dict, prevKey, newKey);
    if (!("" in newDict)) newDict[""] = "";
    props.onChange(newDict);
  };

  const form = [];
  Object.keys(dict).forEach((key, index) => {
    let label = (
      <span>
        {props.label} {unit}
      </span>
    );
    if (index > 0) {
      label = "";
    }

    let isValid = true;
    if (props.validate !== undefined) {
      isValid = validate(props.validate, dict[key]);
    }

    let className = "";
    if (!isValid) className = form_styles.invalid;

    form.push(
      <div className={form_styles.FormRow} key={index}>
        <label>{label}</label>
        <input
          type="text"
          data-index={index}
          value={key}
          placeholder={props.keyPlaceholder}
          disabled={props.disableKeys}
          onChange={(e) => onChangeKey(key, e.target.value)}
        />
        <input
          type="text"
          data-index={index}
          value={dict[key]}
          placeholder={props.valuePlaceholder}
          className={className}
          onChange={(e) => onChangeValue(key, e.target.value)}
        />
        {tooltip}
      </div>
    );
  });

  return <>{form}</>;
};

export function renameKey(obj, prevKey, newKey) {
  const keys = Object.keys(obj);
  return keys.reduce((acc, val) => {
    if (val === prevKey) {
      acc[newKey] = obj[prevKey];
    } else {
      acc[val] = obj[val];
    }
    return acc;
  }, {});
}

export default DictInputRow;
