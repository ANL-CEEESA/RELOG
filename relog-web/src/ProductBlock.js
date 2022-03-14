import Section from './Section'
import Card from './Card'
import Form from './Form'
import TextInputRow from './TextInputRow'
import FileInputRow from './FileInputRow'

const ProductBlock = (props) => {
    return (
        <>
            <Section title={props.name} />
            <Card>
                <Form>
                    <h1>General information</h1>
                    <FileInputRow
                        label="Initial amounts"
                        tooltip="A dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted."
                    />
                    <TextInputRow
                        label="Acquisition cost"
                        unit="$/tonne"
                        tooltip="The cost to acquire one tonne of this product from collection centers. Does not apply to plant outputs."
                        default="0.00"
                    />

                    <h1>Disposal</h1>
                    <TextInputRow
                        label="Disposal cost"
                        unit="$/tonne"
                        tooltip="The cost to dispose of one tonne of this product at a collection center, without further processing. Does not apply to plant outputs."
                        default="0"
                    />
                    <TextInputRow
                        label="Disposal limit"
                        unit="tonne"
                        tooltip="The maximum amount of this product that can be disposed of across all collection centers, without further processing."
                        default="0"
                    />

                    <h1>Transportation</h1>
                    <TextInputRow
                        label="Transportation cost"
                        unit="$/km/tonne"
                        tooltip="The cost to transport this product."
                        default="0.00"
                    />
                    <TextInputRow
                        label="Transportation energy"
                        unit="J/km/tonne"
                        default="0"
                        tooltip="The energy required to transport this product."
                    />
                    <TextInputRow
                        label="Transportation emissions"
                        unit="J/km/tonne"
                        tooltip="A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced (in tonnes)."
                        default="0"
                    />
                </Form>
            </Card>
        </>
    )
}

export default ProductBlock;