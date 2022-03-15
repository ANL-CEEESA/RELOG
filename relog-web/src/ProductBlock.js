import { useState } from 'react';
import Section from './Section';
import Card from './Card';
import Form from './Form';
import TextInputRow from './TextInputRow';
import FileInputRow from './FileInputRow';
import DictInputRow from './DictInputRow';

const ProductBlock = (props) => {
    const onChange = (field, val) => {
        const newProduct = { ...props.value };
        newProduct[field] = val;
        props.onChange(newProduct);
    };

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
                        value={props.value["acquisition cost ($/tonne)"]}
                        onChange={v => onChange("acquisition cost ($/tonne)", v)}
                    />

                    <h1>Disposal</h1>
                    <TextInputRow
                        label="Disposal cost"
                        unit="$/tonne"
                        tooltip="The cost to dispose of one tonne of this product at a collection center, without further processing. Does not apply to plant outputs."
                        value={props.value["disposal cost ($/tonne)"]}
                        onChange={v => onChange("disposal cost ($/tonne)", v)}
                    />
                    <TextInputRow
                        label="Disposal limit"
                        unit="tonne"
                        tooltip="The maximum amount of this product that can be disposed of across all collection centers, without further processing."
                        value={props.value["disposal limit (tonne)"]}
                        onChange={v => onChange("disposal limit (tonne)", v)}
                    />

                    <h1>Transportation</h1>
                    <TextInputRow
                        label="Transportation cost"
                        unit="$/km/tonne"
                        tooltip="The cost to transport this product."
                        value={props.value["transportation cost ($/km/tonne)"]}
                        onChange={v => onChange("transportation cost ($/km/tonne)", v)}
                    />
                    <TextInputRow
                        label="Transportation energy"
                        unit="J/km/tonne"
                        tooltip="The energy required to transport this product."
                        value={props.value["transportation energy (J/km/tonne)"]}
                        onChange={v => onChange("transportation energy (J/km/tonne)", v)}
                    />
                    <DictInputRow
                        label="Transportation emissions"
                        unit="J/km/tonne"
                        tooltip="A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced (in tonnes)."
                        keyPlaceholder="Emission name"
                        valuePlaceholder="0"
                        value={props.value["transportation emissions (J/km/tonne)"]}
                        onChange={v => onChange("transportation emissions (J/km/tonne)", v)}
                    />
                </Form>
            </Card>
        </>
    );
};

export default ProductBlock;