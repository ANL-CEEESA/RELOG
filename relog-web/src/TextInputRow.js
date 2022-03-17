import form_styles from "./Form.module.css";
import Button from "./Button";
import { validate } from "./Form";
import React from "react";

const TextInputRow = React.forwardRef((props, ref) => {
  let unit = "";
  if (props.unit) {
    unit = <span className={form_styles.FormRow_unit}>({props.unit})</span>;
  }

  let tooltip = "";
  if (props.tooltip !== undefined) {
    tooltip = <Button label="?" kind="inline" tooltip={props.tooltip} />;
  }

  let isValid = true;
  if (!props.disabled && props.validate !== undefined) {
    isValid = validate(props.validate, props.value);
  }

  let className = "";
  if (!isValid) className = form_styles.invalid;

  return (
    <div className={form_styles.FormRow}>
      <label>
        {props.label} {unit}
      </label>
      <input
        type="text"
        placeholder={props.default}
        disabled={props.disabled}
        value={props.value}
        className={className}
        onChange={(e) => props.onChange(e.target.value)}
        ref={ref}
      />
      {tooltip}
    </div>
  );
});

export default TextInputRow;
