const VALIDATION_REGEX = {
  int: new RegExp("^[0-9]+$"),
  intList: new RegExp("[[0-9]*]$"),
  float: new RegExp("^[0-9]*\\.?[0-9]*$"),
  floatList: new RegExp("^[?[0-9,.]*]?$"),
};

export const validate = (kind, value) => {
  if (!VALIDATION_REGEX[kind].test(value)) {
    return false;
  }
  return true;
};

const Form = (props) => {
  return <>{props.children}</>;
};

export default Form;
