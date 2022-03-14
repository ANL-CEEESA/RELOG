import Section from './Section'
import Card from './Card'
import Form from './Form'
import TextInputRow from './TextInputRow'
import FileInputRow from './FileInputRow'
import DictInputRow from './DictInputRow'

const PlantBlock = (props) => {
    const emissions = {
        "CO2": "0.05",
        "CH4": "0.01",
        "N2O": "0.04",
    }
    const output = {
        "Nickel": "0.5",
        "Metal casing": "0.35",
    }
    return (
        <>
            <Section title={props.name} />
            <Card>
                <Form>
                    <h1>General information</h1>
                    <FileInputRow
                        label="Candidate locations"
                        tooltip="A dictionary mapping the name of the location to a dictionary which describes the site characteristics."
                    />


                    <h1>Inputs & Outputs</h1>
                    <TextInputRow
                        label="Input"
                        tooltip="The name of the product that this plant takes as input. Only one input is accepted per plant."
                        disabled="disabled"
                        value="Battery"
                    />
                    <DictInputRow
                        label="Outputs"
                        unit="tonne/tonne"
                        tooltip="A dictionary specifying how many tonnes of each product is produced for each tonnes of input. If the plant does not output anything, this key may be omitted."
                        value={output}
                        disableKeys={true}
                        default="0"
                    />

                    <h1>Capacity & costs</h1>
                    <TextInputRow
                        label="Minimum capacity"
                        unit="tonne"
                        tooltip="The minimum size of the plant."
                        default="0"
                    />
                    <TextInputRow
                        label="Opening cost (min capacity)"
                        unit="$"
                        tooltip="The cost to open the plant at minimum capacity."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Fixed operating cost (min capacity)"
                        unit="$"
                        tooltip="The cost to keep the plant open, even if the plant doesn't process anything."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Maximum capacity"
                        unit="tonne"
                        tooltip="The maximum size of the plant."
                        default="0"
                    />
                    <TextInputRow
                        label="Opening cost (max capacity)"
                        unit="$"
                        tooltip="The cost to open a plant of this size."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Fixed operating cost (max capacity)"
                        unit="$"
                        tooltip="The cost to keep the plant open, even if the plant doesn't process anything."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Variable operating cost"
                        unit="$"
                        tooltip="The cost that the plant incurs to process each tonne of input."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Energy expenditure"
                        unit="GJ/tonne"
                        tooltip="The energy required to process 1 tonne of the input."
                        default="0"
                    />

                    <h1>Storage</h1>
                    <TextInputRow
                        label="Storage cost"
                        unit="$/tonne"
                        tooltip="The cost to store a tonne of input product for one time period."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Storage limit"
                        unit="tonne"
                        tooltip="The maximum amount of input product this plant can have in storage at any given time."
                        default="0"
                    />

                    <h1>Disposal</h1>
                    <DictInputRow
                        label="Disposal cost"
                        unit="$/tonne"
                        tooltip="The cost to dispose of the product."
                        value={output}
                        disableKeys={true}
                    />
                    <DictInputRow
                        label="Disposal limit"
                        unit="tonne"
                        tooltip="The maximum amount that can be disposed of. If an unlimited amount can be disposed, this key may be omitted."
                        value={output}
                        disableKeys={true}
                    />

                    <h1>Emissions</h1>
                    <DictInputRow
                        label="Emissions"
                        unit="tonne/tonne"
                        tooltip="A dictionary mapping the name of each greenhouse gas, produced to process each tonne of input, to the amount of gas produced (in tonne)."
                        value={emissions}
                        keyPlaceholder="Emission name"
                        valuePlaceholder="0"
                    />

                </Form>
            </Card>
        </>
    )
}

export default PlantBlock;