import React, { useState } from 'react';

import './index.css';
import PipelineBlock from './PipelineBlock';
import ParametersBlock from './ParametersBlock';
import ProductBlock from './ProductBlock';
import PlantBlock from './PlantBlock';
import ButtonRow from './ButtonRow';
import Button from './Button';

const defaultData = {
    parameters: {
        "time horizon (years)": "1",
        "building period (years)": "[1]",
        "annual inflation rate (%)": "0.0",
    },
    products: {
    },
    plants: {
    }
};

const defaultProduct = {
    "acquisition cost ($/tonne)": "0.00",
    "disposal cost ($/tonne)": "0.00",
    "disposal limit (tonne)": "0",
    "transportation cost ($/km/tonne)": "0.00",
    "transportation energy (J/km/tonne)": "0",
    "transportation emissions (J/km/tonne)": {
        "CO2": 0,
        "NH2": 0,
    }
};

const randomPosition = () => {
    return Math.round(Math.random() * 30) * 15;
};

const InputPage = () => {
    let [data, setData] = useState(defaultData);

    // onAdd
    // ------------------------------------------------------------------------
    const promptName = (prevData) => {
        const name = prompt("Name");
        if (!name || name.length == 0) return;
        if (name in prevData.products || name in prevData.plants) return;
        return name;
    };

    const onAddPlant = () => {
        setData((prevData) => {
            const name = promptName(prevData);
            if (name === undefined) return prevData;
            const newData = { ...prevData };
            newData.plants[name] = {
                x: randomPosition(),
                y: randomPosition(),
                outputs: {},
            };
            return newData;
        });
    };

    const onAddProduct = () => {
        setData((prevData) => {
            const name = promptName(prevData);
            if (name === undefined) return prevData;
            const newData = { ...prevData };
            newData.products[name] = {
                ...defaultProduct,
                x: randomPosition(),
                y: randomPosition(),
            };
            return newData;
        });
    };

    // onRename
    // ------------------------------------------------------------------------
    const onRenamePlant = (prevName, newName) => {
        setData((prevData) => {
            const newData = { ...prevData };
            newData.plants[newName] = newData.plants[prevName];
            delete newData.plants[prevName];
            return newData;
        });
    };

    const onRenameProduct = (prevName, newName) => {
        setData((prevData) => {
            const newData = { ...prevData };
            newData.products[newName] = newData.products[prevName];
            delete newData.products[prevName];
            for (const [plantName, plant] of Object.entries(newData.plants)) {
                if (plant.input == prevName) {
                    plant.input = newName;
                }
                let outputFound = false;
                for (const [outputName, outputValue] of Object.entries(plant.outputs)) {
                    if (outputName == prevName) outputFound = true;
                }
                if (outputFound) {
                    plant.outputs[newName] = plant.outputs[prevName];
                    delete plant.outputs[prevName];
                }
            }
            return newData;
        });
    };

    // onMove
    // ------------------------------------------------------------------------
    const onMovePlant = (plantName, x, y) => {
        setData((prevData) => {
            const newData = { ...prevData };
            newData.plants[plantName].x = x;
            newData.plants[plantName].y = y;
            return newData;
        });
    };

    const onMoveProduct = (productName, x, y) => {
        setData((prevData) => {
            const newData = { ...prevData };
            newData.products[productName].x = x;
            newData.products[productName].y = y;
            return newData;
        });
    };

    // onRemove
    // ------------------------------------------------------------------------
    const onRemovePlant = (plantName) => {
        setData((prevData) => {
            const newData = { ...prevData };
            delete newData.plants[plantName];
            return newData;
        });
    };

    const onRemoveProduct = (productName) => {
        setData((prevData) => {
            const newData = { ...prevData };
            delete newData.products[productName];
            for (const [plantName, plant] of Object.entries(newData.plants)) {
                if (plant.input == productName) {
                    delete plant.input;
                }
                let outputFound = false;
                for (const [outputName, outputValue] of Object.entries(plant.outputs)) {
                    if (outputName == productName) outputFound = true;
                }
                if (outputFound) {
                    delete plant.outputs[productName];
                }
            }
            return newData;
        });
    };

    // Inputs & Outputs
    // ------------------------------------------------------------------------
    const onSetPlantInput = (plantName, productName) => {
        setData((prevData) => {
            const newData = { ...prevData };
            newData.plants[plantName].input = productName;
            return newData;
        });
    };

    const onAddPlantOutput = (plantName, productName) => {
        setData((prevData) => {
            if (productName in prevData.plants[plantName].outputs) {
                return prevData;
            }
            const newData = { ...prevData };
            newData.plants[plantName].outputs[productName] = 0;
            return newData;
        });

    };

    // onSave
    // ------------------------------------------------------------------------
    const onSave = () => {
        console.log(data);
    };

    // onChange
    // ------------------------------------------------------------------------
    const onChangeParameters = (val) => {
        setData(prevData => {
            const newData = { ...prevData };
            newData.parameters = val;
            return newData;
        });
    };

    const onChangeProduct = (prodName, val) => {
        setData(prevData => {
            const newData = { ...prevData };
            newData.products[prodName] = val;
            return newData;
        });
    };

    // ------------------------------------------------------------------------
    let productComps = [];
    for (const [prodName, prod] of Object.entries(data.products)) {
        productComps.push(
            <ProductBlock
                key={prodName}
                name={prodName}
                value={prod}
                onChange={v => onChangeProduct(prodName, v)}
            />
        );
    }

    let plantComps = [];
    for (const [plantName, plant] of Object.entries(data.plants)) {
        plantComps.push(
            <PlantBlock key={plantName} name={plantName} />
        );
    }

    return <>
        <PipelineBlock
            onAddPlant={onAddPlant}
            onAddPlantOutput={onAddPlantOutput}
            onAddProduct={onAddProduct}
            onMovePlant={onMovePlant}
            onMoveProduct={onMoveProduct}
            onRenamePlant={onRenamePlant}
            onRenameProduct={onRenameProduct}
            onSetPlantInput={onSetPlantInput}
            onRemovePlant={onRemovePlant}
            onRemoveProduct={onRemoveProduct}
            plants={data.plants}
            products={data.products}
        />
        <ParametersBlock
            value={data.parameters}
            onChange={onChangeParameters}
        />
        {productComps}
        {plantComps}
        <ButtonRow>
            <Button label="Load" />
            <Button label="Save" onClick={onSave} />
        </ButtonRow>
    </>;
};

export default InputPage;