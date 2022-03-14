import Section from './Section'
import Card from './Card'
import Form from './Form'
import TextInputRow from './TextInputRow'

const ParametersBlock = () => {
    return (
        <>
            <Section title="Parameters" />
            <Card>
                <Form>
                    <TextInputRow
                        label="Time horizon"
                        unit="years"
                        tooltip="Number of years in the simulation."
                        default="1"
                    />
                    <TextInputRow
                        label="Building period"
                        unit="years"
                        tooltip="List of years in which we are allowed to open new plants. For example, if this parameter is set to [1,2,3], we can only open plants during the first three years. By default, this equals [1]; that is, plants can only be opened during the first year."
                        default="[1]"
                    />
                    <TextInputRow
                        label="Annual inflation rate"
                        unit="%"
                        tooltip="Rate of inflation applied to all costs."
                        default="0"
                    />
                </Form>
            </Card>
        </>
    )
}

export default ParametersBlock;