import form_styles from "./Form.module.css";
import Button from "./Button";
import { useRef } from "react";

const FileInputRow = (props) => {
  let tooltip = "";
  if (props.tooltip !== undefined) {
    tooltip = <Button label="?" kind="inline" tooltip={props.tooltip} />;
  }

  const fileElem = useRef();

  const onClickUpload = () => {
    fileElem.current.click();
  };

  const onFileSelected = () => {
    const file = fileElem.current.files[0];
    if (file) {
      const reader = new FileReader();
      reader.addEventListener("load", () => {
        props.onFile(reader.result);
      });
      reader.readAsText(file);
    }
    fileElem.current.value = "";
  };

  return (
    <div className={form_styles.FormRow}>
      <label>{props.label}</label>
      <input type="text" value={props.value} disabled="disabled" />
      <Button label="Upload" kind="inline" onClick={onClickUpload} />
      <Button
        label="Download"
        kind="inline"
        onClick={props.onDownload}
        disabled={props.disableDownload}
      />
      <Button
        label="Clear"
        kind="inline"
        onClick={props.onClear}
        disabled={props.disableClear}
      />
      <Button label="Template" kind="inline" onClick={props.onTemplate} />
      {tooltip}
      <input
        type="file"
        ref={fileElem}
        accept={props.accept}
        style={{ display: "none" }}
        onChange={onFileSelected}
      />
    </div>
  );
};

export default FileInputRow;
