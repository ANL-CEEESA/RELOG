import Section from "../common/Section";
import Card from "../common/Card";
import Form from "../common/Form";
import TextInputRow from "../common/TextInputRow";

const ParametersBlock = (props) => {
  const onChangeField = (field, val) => {
    props.value[field] = val;
    props.onChange(props.value);
  };
  return (
    <>
      <Section title="Parameters" />
      <Card>
        <Form>
          <TextInputRow
            label="Time horizon"
            unit="years"
            tooltip="Number of years in the simulation."
            value={props.value["time horizon (years)"]}
            onChange={(v) => onChangeField("time horizon (years)", v)}
            validate="int"
          />
          <TextInputRow
            label="Building period"
            unit="years"
            tooltip="List of years in which we are allowed to open new plants. For example, if this parameter is set to [1,2,3], we can only open plants during the first three years. By default, this equals [1]; that is, plants can only be opened during the first year."
            value={props.value["building period (years)"]}
            onChange={(v) => onChangeField("building period (years)", v)}
            validate="intList"
          />
          <TextInputRow
            label="Inflation rate"
            unit="%"
            tooltip="Rate at which costs change from one time period to the next. This is applied uniformly to all costs."
            value={props.value["inflation rate (%)"]}
            onChange={(v) => onChangeField("inflation rate (%)", v)}
            validate="float"
          />
          <TextInputRow
            label="Distance metric"
            tooltip="Metric used to compute distances between pairs of locations. Valid options are: 'Euclidean', for the straight-line distance between points; or 'driving' for an approximated driving distance."
            value={props.value["distance metric"]}
            onChange={(v) => onChangeField("distance metric", v)}
            default="Euclidean"
          />
        </Form>
      </Card>
    </>
  );
};

export default ParametersBlock;
