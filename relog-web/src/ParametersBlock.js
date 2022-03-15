import Section from './Section';
import Card from './Card';
import Form from './Form';
import TextInputRow from './TextInputRow';

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
                        onChange={v => onChangeField("time horizon (years)", v)}
                    />
                    <TextInputRow
                        label="Building period"
                        unit="years"
                        tooltip="List of years in which we are allowed to open new plants. For example, if this parameter is set to [1,2,3], we can only open plants during the first three years. By default, this equals [1]; that is, plants can only be opened during the first year."
                        value={props.value["building period (years)"]}
                        onChange={v => onChangeField("building period (years)", v)}
                    />
                    <TextInputRow
                        label="Annual inflation rate"
                        unit="%"
                        tooltip="Rate of inflation applied to all costs."
                        value={props.value["annual inflation rate (%)"]}
                        onChange={v => onChangeField("annual inflation rate (%)", v)}
                    />
                </Form>
            </Card>
        </>
    );
};

export default ParametersBlock;